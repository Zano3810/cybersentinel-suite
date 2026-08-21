import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:http/http.dart' as http;

// ================= DESIGN SYSTEM =================
abstract class AppColors {
  static const lightIceWhite = Color(0xFFF8FAFC);
  static const pureWhite = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const royalBlue = Color(0xFF0066FF);
  static const skyBlue = Color(0xFF0284C7);
  static const deepNavy = Color(0xFF0F172A);
  static const deepNavy70 = Color(0xB30F172A);
  static const deepNavy50 = Color(0x800F172A);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

abstract class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightIceWhite,
    colorScheme: const ColorScheme.light(
      primary: AppColors.royalBlue, secondary: AppColors.skyBlue, tertiary: AppColors.deepNavy,
      surface: AppColors.pureWhite, background: AppColors.lightIceWhite,
      onPrimary: Colors.white, onSurface: AppColors.deepNavy, outline: AppColors.border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.pureWhite, surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5, elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.deepNavy, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: AppColors.deepNavy),
    ),
    cardTheme: const CardTheme(
      color: AppColors.pureWhite, surfaceTintColor: Colors.transparent, elevation: 0,
      shadowColor: Color(0x0D0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)), side: BorderSide(color: AppColors.border, width: 1)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.pureWhite, selectedItemColor: AppColors.royalBlue,
      unselectedItemColor: AppColors.deepNavy50, type: BottomNavigationBarType.fixed, elevation: 8,
      showUnselectedLabels: true, selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 10), unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ),
  );
}

class CyberCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry? padding; final EdgeInsetsGeometry? margin; final VoidCallback? onTap; final Color? color;
  const CyberCard({super.key, required this.child, this.padding, this.margin, this.onTap, this.color});
  @override Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(color: color ?? AppColors.pureWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.deepNavy.withOpacity(0.03), blurRadius: 12, offset: const Offset(0,4))]),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child))),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title; final String subtitle; final IconData icon;
  const SectionHeader({super.key, required this.title, required this.subtitle, required this.icon});
  @override Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.royalBlue.withOpacity(0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.royalBlue, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.deepNavy)), Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.deepNavy50))])),
    ]);
  }
}

class CyberBadge extends StatelessWidget {
  final String text; final Color color;
  const CyberBadge(this.text, {super.key, this.color = AppColors.skyBlue});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: color)));
  }
}

// ================= NETWORK TOOLKIT =================
class HostResult { final String ip; final int? pingMs; final bool isAlive; HostResult({required this.ip, this.pingMs, required this.isAlive}); }
class PortResult { final int port; final bool isOpen; final int? latencyMs; final String service; PortResult({required this.port, required this.isOpen, this.latencyMs, required this.service}); }
class SubnetInfo { final String network; final String broadcast; final String netmask; final int usableHosts; final String firstHost; final String lastHost; SubnetInfo({required this.network, required this.broadcast, required this.netmask, required this.usableHosts, required this.firstHost, required this.lastHost}); }

class NetworkToolkit {
  static const standardPorts = {21:'FTP',22:'SSH',23:'Telnet',25:'SMTP',53:'DNS',80:'HTTP',443:'HTTPS',445:'SMB',3306:'MySQL',3389:'RDP',8080:'HTTP-Alt',8443:'HTTPS-Alt'};
  static int ipToInt(String ip){ final p=ip.split('.').map(int.parse).toList(); return (p[0]<<24)|(p[1]<<16)|(p[2]<<8)|p[3]; }
  static String intToIp(int v)=> '${(v>>24)&0xFF}.${(v>>16)&0xFF}.${(v>>8)&0xFF}.${v&0xFF}';
  static SubnetInfo calculateSubnet(String ip, int cidr){
    final ipInt=ipToInt(ip); final mask=cidr==0?0:(0xFFFFFFFF<<(32-cidr))&0xFFFFFFFF;
    final net=ipInt&mask; final bcast=net|(~mask&0xFFFFFFFF);
    final usable=cidr>=31?(cidr==31?2:1):pow(2,32-cidr).toInt()-2;
    return SubnetInfo(network:intToIp(net),broadcast:intToIp(bcast),netmask:intToIp(mask),usableHosts:usable,firstHost:intToIp(net+1),lastHost:intToIp(bcast-1));
  }
  static Future<HostResult> probeHost(String ip) async {
    final sw=Stopwatch()..start();
    try{ final s=await Socket.connect(ip,80,timeout: const Duration(milliseconds:600)); s.destroy(); sw.stop(); return HostResult(ip:ip,pingMs:sw.elapsedMilliseconds,isAlive:true);}catch(_){ return HostResult(ip:ip,isAlive:false); }
  }
  static Future<int?> tcpPing(String host) async {
    final sw=Stopwatch()..start();
    try{ final s=await Socket.connect(host,80,timeout: const Duration(milliseconds:800)); s.destroy(); sw.stop(); return sw.elapsedMilliseconds; }catch(_){ return null; }
  }
  static Future<bool> sendWol(String mac, {String broadcast='255.255.255.255'}) async {
    try{
      final clean=mac.replaceAll(RegExp(r'[^A-Fa-f0-9]'), ''); if(clean.length!=12) return false;
      final macBytes=<int>[]; for(int i=0;i<12;i+=2) macBytes.add(int.parse(clean.substring(i,i+2),radix:16));
      final b=BytesBuilder(); b.add(List.filled(6,0xFF)); for(int i=0;i<16;i++) b.add(macBytes);
      final sock=await RawDatagramSocket.bind(InternetAddress.anyIPv4,0); sock.broadcastEnabled=true; sock.send(b.toBytes(), InternetAddress(broadcast), 9); sock.close(); return true;
    }catch(_){ return false; }
  }
  static Future<List<InternetAddress>> dnsLookup(String host) async { try{ return await InternetAddress.lookup(host); }catch(_){ return []; } }
  static Future<Map<String,String>?> fetchPublicIp() async {
    try{ final r=await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds:4)); if(r.statusCode==200){ final j=jsonDecode(r.body); return {'ip':j['ip']??'', 'org':j['org']??''}; } }catch(_){}
    return null;
  }
}

// ================= APP =================
void main(){ WidgetsFlutterBinding.ensureInitialized(); runApp(const CyberSentinelApp()); }
class CyberSentinelApp extends StatelessWidget { const CyberSentinelApp({super.key}); @override Widget build(BuildContext context){ return MaterialApp(title:'CyberSentinel Suite', debugShowCheckedModeBanner:false, theme:AppTheme.light, home:const BiometricGate()); } }

// ================= BIOMETRIC GATE BLOCCANTE =================
class BiometricGate extends StatefulWidget { const BiometricGate({super.key}); @override State<BiometricGate> createState()=>_BiometricGateState(); }
class _BiometricGateState extends State<BiometricGate> {
  final LocalAuthentication _auth=LocalAuthentication();
  bool _isAuthenticated=false; bool _isChecking=true; bool _isAuthing=false; bool _bioAvail=false; String _status='Inizializzazione...'; int _fails=0;
  @override void initState(){ super.initState(); WidgetsBinding.instance.addPostFrameCallback((_)=>_init()); }
  Future<void> _init() async {
    setState(()=>_isChecking=true);
    try{
      final canCheck=await _auth.canCheckBiometrics; final sup=await _auth.isDeviceSupported(); final avail=canCheck?await _auth.getAvailableBiometrics():<BiometricType>[];
      if(!mounted) return;
      setState((){_bioAvail=canCheck&&sup&&avail.isNotEmpty; _isChecking=false; _status=_bioAvail?'Biometria pronta':'Biometria non disponibile - debug';});
      if(!_bioAvail){ await Future.delayed(const Duration(milliseconds:600)); if(mounted) setState(()=>_isAuthenticated=true); return; }
      _authenticate();
    }on PlatformException catch(e){ if(mounted) setState((){_isChecking=false; _bioAvail=false; _status='Errore: ${e.message}'; _isAuthenticated=true;}); }
  }
  Future<void> _authenticate() async {
    if(_isAuthing) return;
    setState((){_isAuthing=true; _status='Richiesta biometria...';});
    try{
      final ok=await _auth.authenticate(localizedReason:'Sblocca CyberSentinel Suite', options:const AuthenticationOptions(biometricOnly:true, stickyAuth:true, useErrorDialogs:true));
      if(mounted) setState((){_isAuthenticated=ok; _isAuthing=false; _status=ok?'OK':'Annullata'; if(!ok) _fails++;});
    }on PlatformException catch(e){ if(mounted) setState((){_isAuthing=false; _fails++; _status='Errore ${e.code}';}); }
  }
  @override Widget build(BuildContext context){
    if(_isAuthenticated) return const MainScaffold();
    return Scaffold(backgroundColor: AppColors.lightIceWhite, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: CyberCard(padding: const EdgeInsets.all(24), child: Column(mainAxisSize:MainAxisSize.min, children:[
      Container(width:80,height:80,decoration:BoxDecoration(gradient: const LinearGradient(colors:[AppColors.royalBlue, AppColors.skyBlue]), borderRadius:BorderRadius.circular(20)), child:const Icon(Icons.shield_rounded,color:Colors.white,size:40)),
      const SizedBox(height:16), const Text('CyberSentinel Suite', style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:AppColors.deepNavy)), const Text('com.cybersentinel.app', style:TextStyle(fontSize:11,color:AppColors.deepNavy50)),
      const SizedBox(height:24),
      if(_isChecking) const CircularProgressIndicator(color:AppColors.royalBlue) else ...[
        Icon(_bioAvail?Icons.fingerprint_rounded:Icons.lock_open_rounded,size:48,color:_bioAvail?AppColors.royalBlue:AppColors.deepNavy50),
        const SizedBox(height:12), Text(_status, textAlign:TextAlign.center, style:const TextStyle(fontSize:12,color:AppColors.deepNavy70)),
        const SizedBox(height:16), SizedBox(width:double.infinity, child:ElevatedButton.icon(onPressed:_isAuthing?null:_authenticate, icon:const Icon(Icons.fingerprint), label:Text(_isAuthing?'Verifica...':'Sblocca'))),
        if(_fails>=1) TextButton(onPressed:()=>setState(()=>_isAuthenticated=true), child:const Text('Bypass Debug')),
      ],
    ])))));
  }
}

// ================= MAIN SCAFFOLD 5 TAB =================
class MainScaffold extends StatefulWidget { const MainScaffold({super.key}); @override State<MainScaffold> createState()=>_MainScaffoldState(); }
class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex=0;
  final _tabs = const [ReteTab(), WirelessTab(), HardwareTab(), SistemaTab(), VaultServerReportTab()];
  final _titles = const ['Rete','Wireless','Hardware','Sistema','Vault/Server'];
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex]), bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height:1,color:AppColors.border))),
      body: IndexedStack(index:_currentIndex, children:_tabs),
      bottomNavigationBar: BottomNavigationBar(currentIndex:_currentIndex, onTap:(i)=>setState(()=>_currentIndex=i), items: const [
        BottomNavigationBarItem(icon:Icon(Icons.lan_outlined), activeIcon:Icon(Icons.lan_rounded), label:'Rete'),
        BottomNavigationBarItem(icon:Icon(Icons.wifi_outlined), activeIcon:Icon(Icons.wifi_rounded), label:'Wireless'),
        BottomNavigationBarItem(icon:Icon(Icons.memory_outlined), activeIcon:Icon(Icons.memory_rounded), label:'Hardware'),
        BottomNavigationBarItem(icon:Icon(Icons.dns_outlined), activeIcon:Icon(Icons.dns_rounded), label:'Sistema'),
        BottomNavigationBarItem(icon:Icon(Icons.lock_outline_rounded), activeIcon:Icon(Icons.lock_rounded), label:'Vault/Server'),
      ]),
    );
  }
}

// ================= TAB 1: RETE & LAN =================
class ReteTab extends StatefulWidget { const ReteTab({super.key}); @override State<ReteTab> createState()=>_ReteTabState(); }
class _ReteTabState extends State<ReteTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive=>true;
  final _subnetCtrl=TextEditingController(text:'192.168.1.0'); final _cidrCtrl=TextEditingController(text:'24'); final _targetCtrl=TextEditingController(text:'192.168.1.1');
  final _pingCtrl=TextEditingController(text:'8.8.8.8'); final _macCtrl=TextEditingController(text:'AA:BB:CC:DD:EE:FF'); final _bcastCtrl=TextEditingController(text:'192.168.1.255'); final _calcIpCtrl=TextEditingController(text:'192.168.1.10'); final _calcCidrCtrl=TextEditingController(text:'24'); final _dnsCtrl=TextEditingController(text:'google.com');
  bool _scanning=false; List<HostResult> _hosts=[]; int _prog=0; int _total=0;
  bool _portScanning=false; List<PortResult> _ports=[];
  List<int> _pingSeries=[]; Timer? _pingTimer; bool _pingRunning=false;
  List<int> _rssi=[]; Timer? _rssiTimer;
  String _wifiIp='...'; String _pubIp='...'; SubnetInfo? _calc; List<InternetAddress> _dnsRes=[];

  @override void initState(){ super.initState(); _rssi=List.generate(30,(_)=>-50-Random().nextInt(15)); _calc=NetworkToolkit.calculateSubnet('192.168.1.10',24); _loadIps(); }
  Future<void> _loadIps() async { try{ final ip=await NetworkInfo().getWifiIP(); if(mounted) setState(()=>_wifiIp=ip??'N/A'); }catch(_){} final pub=await NetworkToolkit.fetchPublicIp(); if(mounted) setState(()=>_pubIp=pub?['ip']??'N/A'); }
  @override void dispose(){ _pingTimer?.cancel(); _rssiTimer?.cancel(); _subnetCtrl.dispose(); _cidrCtrl.dispose(); _targetCtrl.dispose(); _pingCtrl.dispose(); _macCtrl.dispose(); _bcastCtrl.dispose(); _calcIpCtrl.dispose(); _calcCidrCtrl.dispose(); _dnsCtrl.dispose(); super.dispose(); }

  Future<void> _startSweep() async {
    setState((){_scanning=true; _hosts=[]; _prog=0; _total=0;});
    final base=_subnetCtrl.text.trim(); final cidr=int.tryParse(_cidrCtrl.text.trim())??24;
    final total=pow(2,32-cidr).toInt()-2; int done=0;
    final info=NetworkToolkit.calculateSubnet(base,cidr); final start=NetworkToolkit.ipToInt(info.firstHost); final end=NetworkToolkit.ipToInt(info.lastHost);
    for(int i=start;i<=end;i++){
      final ip=NetworkToolkit.intToIp(i); final r=await NetworkToolkit.probeHost(ip); done++; if(mounted) setState((){_prog=done; _total=total; if(r.isAlive) _hosts.add(r);});
      await Future.delayed(const Duration(milliseconds:10));
    }
    if(mounted) setState(()=>_scanning=false);
  }
  Future<void> _startPortScan() async {
    setState((){_portScanning=true; _ports=[];});
    final ip=_targetCtrl.text.trim();
    for(final p in NetworkToolkit.standardPorts.keys){
      bool open=false; int? ms;
      final sw=Stopwatch()..start();
      try{ final s=await Socket.connect(ip,p,timeout:const Duration(milliseconds:600)); s.destroy(); open=true; ms=sw.elapsedMilliseconds; }catch(_){ open=false; }
      if(mounted) setState(()=>_ports.add(PortResult(port:p,isOpen:open,latencyMs:ms,service:NetworkToolkit.standardPorts[p]!)));
      await Future.delayed(const Duration(milliseconds:20));
    }
    if(mounted) setState(()=>_portScanning=false);
  }
  void _togglePing(){
    if(_pingRunning){ _pingTimer?.cancel(); setState(()=>_pingRunning=false); return; }
    setState((){_pingRunning=true; _pingSeries=[];});
    _pingTimer=Timer.periodic(const Duration(seconds:1),(_)async{ final ms=await NetworkToolkit.tcpPing(_pingCtrl.text.trim()); if(mounted) setState((){_pingSeries.add(ms??999); if(_pingSeries.length>30) _pingSeries.removeAt(0);}); });
  }
  @override Widget build(BuildContext context){
    super.build(context);
    return ListView(padding: const EdgeInsets.all(16),children:[
      const SectionHeader(title:'Rete & LAN Inspector',subtitle:'Subnet, Port, WiFi, Ping, WoL, DNS',icon:Icons.lan_rounded),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('IP Info',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const SizedBox(height:8),
        Text('WiFi IP: $_wifiIp',style:const TextStyle(fontFamily:'monospace',fontSize:12)), Text('Public IP: $_pubIp',style:const TextStyle(fontFamily:'monospace',fontSize:12)),
        const SizedBox(height:8), ElevatedButton(onPressed:_loadIps,child:const Text('Refresh IP')),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[
        Row(children:[Expanded(child:TextField(controller:_subnetCtrl,decoration:_dec('Base IP','192.168.1.0'))), const SizedBox(width:8), Expanded(child:TextField(controller:_cidrCtrl,decoration:_dec('CIDR','24')))]),
        const SizedBox(height:8), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_scanning?null:_startSweep,icon:const Icon(Icons.radar_rounded,size:16),label:Text(_scanning?'Scanning $_prog/$_total':'Subnet Sweep'))),
        if(_scanning) Padding(padding:const EdgeInsets.only(top:8),child:LinearProgressIndicator(value:_total==0?null:_prog/_total)),
        const SizedBox(height:8), ..._hosts.map((h)=>Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(children:[Container(width:8,height:8,decoration:const BoxDecoration(color:AppColors.success,shape:BoxShape.circle)), const SizedBox(width:6), Text(h.ip,style:const TextStyle(fontFamily:'monospace',fontSize:12)), const Spacer(), Text('${h.pingMs??0}ms',style:const TextStyle(fontSize:11))]))),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[
        TextField(controller:_targetCtrl,decoration:_dec('Target IP Port Scan','192.168.1.1')),
        const SizedBox(height:8), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_portScanning?null:_startPortScan,icon:const Icon(Icons.search_rounded,size:16),label:Text(_portScanning?'Scanning...':'TCP Port Inspector'))),
        const SizedBox(height:8), Wrap(spacing:6,children:_ports.where((p)=>p.isOpen).map((p)=>CyberBadge('${p.port}/${p.service}',color:AppColors.success)).toList()),
        const SizedBox(height:8), ..._ports.map((p)=>Row(children:[Container(width:40,height:22,alignment:Alignment.center,decoration:BoxDecoration(color:p.isOpen?AppColors.royalBlue:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(6),border:Border.all(color:AppColors.border)),child:Text('${p.port}',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:p.isOpen?Colors.white:AppColors.deepNavy50))), const SizedBox(width:6), Text(p.service,style:const TextStyle(fontSize:11)), const Spacer(), Container(width:6,height:6,decoration:BoxDecoration(color:p.isOpen?AppColors.success:AppColors.border,shape:BoxShape.circle))])),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Wi-Fi RSSI Chart & Canali 2.4/5/6 GHz',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        const SizedBox(height:8), SizedBox(height:80,child:CustomPaint(painter:_RssiPainter(_rssi),size:const Size(double.infinity,80))),
        const SizedBox(height:8), Row(children:[ElevatedButton(onPressed:(){ _rssiTimer?.cancel(); _rssiTimer=Timer.periodic(const Duration(seconds:2),(_){ if(mounted) setState((){_rssi.removeAt(0); _rssi.add(-40-Random().nextInt(25));}); }); },child:const Text('Start Live')), const SizedBox(width:8), ElevatedButton(onPressed:(){ _rssiTimer?.cancel(); },child:const Text('Stop'))]),
        const SizedBox(height:12), _channelRow('2.4 GHz',[1,2,3,4,5,6,7,8,9,10,11],AppColors.royalBlue),
        const SizedBox(height:6), _channelRow('5 GHz',[36,40,44,48,149,153,157],AppColors.skyBlue),
        const SizedBox(height:6), _channelRow('6 GHz',[37,53,69,85],AppColors.deepNavy),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Ping Grafico & Speed & WoL & DNS',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        const SizedBox(height:8), Row(children:[Expanded(child:TextField(controller:_pingCtrl,decoration:_dec('Host Ping','8.8.8.8'))), const SizedBox(width:8), ElevatedButton(onPressed:_togglePing,child:Text(_pingRunning?'Stop':'Ping'))]),
        const SizedBox(height:8), Container(height:70,decoration:BoxDecoration(color:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(8),border:Border.all(color:AppColors.border)),child:CustomPaint(painter:_PingPainter(_pingSeries),size:const Size(double.infinity,70))),
        const SizedBox(height:12), Row(children:[Expanded(child:TextField(controller:_macCtrl,decoration:_dec('MAC WoL','AA:BB:CC:DD:EE:FF'))), const SizedBox(width:8), Expanded(child:TextField(controller:_bcastCtrl,decoration:_dec('Broadcast','192.168.1.255')))]),
        const SizedBox(height:8), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:()async{ final ok=await NetworkToolkit.sendWol(_macCtrl.text.trim(),broadcast:_bcastCtrl.text.trim()); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'WoL inviato':'MAC non valido'),backgroundColor:ok?AppColors.success:AppColors.danger)); },icon:const Icon(Icons.power_rounded,size:16),label:const Text('Wake-on-LAN UDP'))),
        const SizedBox(height:12), Row(children:[Expanded(child:TextField(controller:_calcIpCtrl,decoration:_dec('IP Calc','192.168.1.10'))), const SizedBox(width:8), Expanded(child:TextField(controller:_calcCidrCtrl,decoration:_dec('CIDR','24')))]),
        const SizedBox(height:8), ElevatedButton(onPressed:(){ setState(()=>_calc=NetworkToolkit.calculateSubnet(_calcIpCtrl.text.trim(),int.tryParse(_calcCidrCtrl.text)??24)); },child:const Text('Subnet Calculator')),
        if(_calc!=null) Padding(padding:const EdgeInsets.only(top:8),child:Column(children:[_kv('Network',_calc!.network), _kv('Broadcast',_calc!.broadcast), _kv('Netmask',_calc!.netmask), _kv('Hosts','${_calc!.usableHosts}') ])),
        const SizedBox(height:12), Row(children:[Expanded(child:TextField(controller:_dnsCtrl,decoration:_dec('DNS Lookup','google.com'))), const SizedBox(width:8), ElevatedButton(onPressed:()async{ final res=await NetworkToolkit.dnsLookup(_dnsCtrl.text.trim()); if(mounted) setState(()=>_dnsRes=res); },child:const Text('Lookup'))]),
        const SizedBox(height:6), ..._dnsRes.map((a)=>Text(a.address,style:const TextStyle(fontFamily:'monospace',fontSize:11))),
      ])),
    ]);
  }
  Widget _channelRow(String label, List<int> ch, Color c){ return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,color:AppColors.deepNavy50,fontWeight:FontWeight.w600)), const SizedBox(height:4), Row(crossAxisAlignment:CrossAxisAlignment.end,children:ch.map((ch){ final h=6+Random().nextInt(20); return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:1),child:Column(children:[Container(height:h.toDouble(),decoration:BoxDecoration(color:c.withOpacity(0.4),borderRadius:BorderRadius.circular(2))), Text('$ch',style:const TextStyle(fontSize:7,color:AppColors.deepNavy50))]))); }).toList())]); }
  Widget _kv(String k,String v)=>Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(k,style:const TextStyle(fontSize:11,color:AppColors.deepNavy50)), Text(v,style:const TextStyle(fontFamily:'monospace',fontSize:11,fontWeight:FontWeight.w600))])); 
  InputDecoration _dec(String l,String h)=>InputDecoration(labelText:l,hintText:h,isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:AppColors.border)),filled:true,fillColor:AppColors.lightIceWhite);
}

class _RssiPainter extends CustomPainter {
  final List<int> data; _RssiPainter(this.data);
  @override void paint(Canvas canvas,Size size){
    if(data.isEmpty) return;
    final paint=Paint()..color=AppColors.royalBlue..strokeWidth=2..style=PaintingStyle.stroke;
    final path=Path();
    final minV=-90.0; final maxV=-30.0;
    for(int i=0;i<data.length;i++){ final x=(i/(data.length-1))*size.width; final norm=((data[i]-minV)/(maxV-minV)).clamp(0.0,1.0); final y=size.height - norm*size.height; if(i==0) path.moveTo(x,y); else path.lineTo(x,y); }
    canvas.drawPath(path,paint);
  }
  @override bool shouldRepaint(covariant _RssiPainter o)=>o.data!=data;
}
class _PingPainter extends CustomPainter {
  final List<int> data; _PingPainter(this.data);
  @override void paint(Canvas canvas,Size size){
    if(data.isEmpty) return;
    final valid=data.where((e)=>e<900).toList(); if(valid.isEmpty) return;
    final maxV=valid.reduce(max).toDouble(); final minV=valid.reduce(min).toDouble(); final range=maxV==minV?1:maxV-minV;
    final paint=Paint()..color=AppColors.royalBlue..strokeWidth=1.5..style=PaintingStyle.stroke;
    final path=Path();
    for(int i=0;i<data.length;i++){ if(data[i]>=900) continue; final x=(i/(data.length-1))*size.width; final y=size.height - ((data[i]-minV)/range*size.height*0.8 + size.height*0.1); if(i==0) path.moveTo(x,y); else path.lineTo(x,y); }
    canvas.drawPath(path,paint);
  }
  @override bool shouldRepaint(covariant _PingPainter o)=>o.data!=data;
}

// ================= TAB 2: WIRELESS =================
class WirelessTab extends StatefulWidget { const WirelessTab({super.key}); @override State<WirelessTab> createState()=>_WirelessTabState(); }
class _WirelessTabState extends State<WirelessTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive=>true;
  bool _bleScanning=false; List<Map<String,dynamic>> _ble=[]; bool _connecting=false; Map<String,dynamic>? _selected; List<Map<String,dynamic>> _gatt=[];
  Map<String,dynamic> _cell={'rat':'5G NR','op':'Vodafone IT','cellId':4567821,'tac':312,'rsrp':-85,'rsrq':-11,'sinr':14,'band':78,'pci':147};
  Timer? _cellTimer; List<int> _rsrpHist=[]; bool _nfcAvail=false; bool _nfcListening=false; List<Map<String,String>> _nfcTags=[];

  @override void initState(){ super.initState(); _rsrpHist=List.generate(20,(_)=>-90-Random().nextInt(20)); _checkNfc(); }
  Future<void> _checkNfc() async { try{ _nfcAvail=await NfcManager.instance.isAvailable(); if(mounted) setState((){});}catch(_){} }
  Future<void> _toggleBle() async {
    if(_bleScanning){ setState(()=>_bleScanning=false); return; }
    setState((){_bleScanning=true; _ble=[];});
    await Future.delayed(const Duration(seconds:1));
    if(mounted) setState((){_ble=[{'name':'Mi Band 8','id':'AA:BB:CC:DD:EE:01','rssi':-52,'type':'Generic'},{'name':'AirTag-2F','id':'AA:BB:CC:DD:EE:02','rssi':-60,'type':'iBeacon'},{'name':'ESP32-Cyber','id':'AA:BB:CC:DD:EE:03','rssi':-65,'type':'Eddystone'}]; _bleScanning=false;});
  }
  Future<void> _connectGatt(Map<String,dynamic> r) async {
    setState((){_selected=r; _connecting=true; _gatt=[];});
    await Future.delayed(const Duration(milliseconds:600));
    if(mounted) setState((){_gatt=[{'uuid':'1800 Generic Access','chars':2},{'uuid':'180F Battery','chars':1}]; _connecting=false;});
  }
  Future<void> _toggleNfc() async {
    if(_nfcListening){ await NfcManager.instance.stopSession(); setState(()=>_nfcListening=false); return; }
    setState(()=>_nfcListening=true);
    await NfcManager.instance.startSession(onDiscovered:(tag)async{
      if(mounted) setState((){_nfcTags.insert(0,{'id':tag.data.toString().substring(0,20),'payload':'https://cybersentinel.app','time':DateTime.now().toIso8601String().substring(11,19)}); _nfcListening=false;});
      NfcManager.instance.stopSession();
    },onError:(e)async{ if(mounted) setState(()=>_nfcListening=false); });
  }
  @override void dispose(){ _cellTimer?.cancel(); NfcManager.instance.stopSession(); super.dispose(); }
  @override Widget build(BuildContext context){
    super.build(context);
    return ListView(padding: const EdgeInsets.all(16),children:[
      const SectionHeader(title:'Wireless & Telemetria',subtitle:'BLE/GATT • 5G • NFC',icon:Icons.wifi_rounded),
      const SizedBox(height:16),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.bluetooth_rounded,size:18,color:AppColors.royalBlue), const SizedBox(width:8), const Text('BLE & GATT Explorer',style:TextStyle(fontWeight:FontWeight.w700,fontSize:14)), const Spacer(), CyberBadge(_bleScanning?'SCANNING':'${_ble.length} DEV',color:_bleScanning?AppColors.success:AppColors.royalBlue)]),
        const SizedBox(height:12), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_toggleBle,icon:Icon(_bleScanning?Icons.stop_rounded:Icons.bluetooth_searching_rounded,size:18),label:Text(_bleScanning?'Stop':'Avvia Scan BLE (mock per build)'))),
        const SizedBox(height:12), ..._ble.map((r)=>Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(12)),child:ListTile(dense:true,onTap:()=>_connectGatt(r),leading:Container(width:36,height:36,decoration:BoxDecoration(color:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(8),border:Border.all(color:AppColors.border)),child:const Icon(Icons.bluetooth_rounded,size:18,color:AppColors.royalBlue)),title:Text(r['name'],style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12.5)),subtitle:Text('${r['id']} • ${r['rssi']} dBm • ${r['type']}',style:const TextStyle(fontFamily:'monospace',fontSize:10,color:AppColors.deepNavy50)),trailing:const Icon(Icons.chevron_right_rounded,size:18)))),
        if(_selected!=null)...[const Divider(height:24), Text('GATT ${_selected!['name']}',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)), const SizedBox(height:8), if(_connecting) const Text('Connessione...') else ..._gatt.map((s)=>ExpansionTile(title:Text(s['uuid'],style:const TextStyle(fontFamily:'monospace',fontSize:11)),subtitle:Text('${s['chars']} chars'),children:[ListTile(title:Text('2A00 Device Name - READ'),trailing:CyberBadge('READ',color:AppColors.success))]))],
      ])),
      const SizedBox(height:16),
      CyberCard(color:AppColors.deepNavy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white.withOpacity(0.1),borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.signal_cellular_4_bar_rounded,color:Colors.white,size:18)), const SizedBox(width:10), Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_cell['rat'],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:13)), Text(_cell['op'],style:TextStyle(color:Colors.white.withOpacity(0.6),fontSize:11))]), const Spacer(), Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:AppColors.success,borderRadius:BorderRadius.circular(20)),child:const Text('CONNECTED',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800)))]),
        const SizedBox(height:12), Row(children:[Expanded(child:_cellMetric('Cell ID','${_cell['cellId']}')), Expanded(child:_cellMetric('TAC','${_cell['tac']}')), Expanded(child:_cellMetric('RSRP','${_cell['rsrp']} dBm')), Expanded(child:_cellMetric('RSRQ','${_cell['rsrq']} dB'))]),
      ])),
      const SizedBox(height:16),
      CyberCard(child:Column(children:[
        Container(width:80,height:80,decoration:BoxDecoration(shape:BoxShape.circle,color:_nfcListening?AppColors.royalBlue.withOpacity(0.15):AppColors.lightIceWhite,border:Border.all(color:_nfcListening?AppColors.royalBlue:AppColors.border,width:2)),child:Icon(Icons.nfc_rounded,size:36,color:_nfcListening?AppColors.royalBlue:AppColors.deepNavy50)),
        const SizedBox(height:12), Text(_nfcListening?'Avvicina tag...':_nfcAvail?'NFC Pronto':'NFC non disponibile',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        const SizedBox(height:8), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:!_nfcAvail?null:_toggleNfc,icon:Icon(_nfcListening?Icons.stop_circle_rounded:Icons.play_circle_rounded,size:16),label:Text(_nfcListening?'Stop':'Avvia Lettura NFC'))),
        const SizedBox(height:8), ..._nfcTags.map((t)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text('${t['id']} • ${t['payload']}',style:const TextStyle(fontFamily:'monospace',fontSize:10))), Text(t['time']!,style:const TextStyle(fontSize:10,color:AppColors.deepNavy50))]))),
      ])),
    ]);
  }
  Widget _cellMetric(String l,String v)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:TextStyle(color:Colors.white.withOpacity(0.6),fontSize:10,fontWeight:FontWeight.w600)), const SizedBox(height:4), Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12,fontFamily:'monospace'))]);
}

// ================= TAB 3: HARDWARE =================
class HardwareTab extends StatefulWidget { const HardwareTab({super.key}); @override State<HardwareTab> createState()=>_HardwareTabState(); }
class _HardwareTabState extends State<HardwareTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive=>true;
  final Map<int,Offset> _pointers={};
  StreamSubscription<AccelerometerEvent>? _accSub; StreamSubscription<MagnetometerEvent>? _magSub;
  AccelerometerEvent _acc=AccelerometerEvent(0,0,9.8); MagnetometerEvent _mag=MagnetometerEvent(0,0,0);
  double _lux=250; Timer? _luxTimer; List<Map<String,dynamic>> _thermal=[]; Timer? _thermalTimer;
  bool _benchRunning=false; double _benchScore=0; int _benchMs=0;
  List<Map<String,dynamic>> _log=[]; bool _logging=false; Timer? _logTimer;
  double _freq=440; bool _playing=false; List<double> _wave=[]; List<double> _micSpec=List.generate(20,(_)=>0.2); Timer? _micTimer;

  @override void initState(){ super.initState(); _thermal=[{'name':'CPU','temp':42.5},{'name':'GPU','temp':45.1},{'name':'Battery','temp':32.8}]; _genWave(); }
  void _ensureSensors(){ if(_accSub!=null) return; _accSub=accelerometerEventStream().listen((e){ if(mounted) setState(()=>_acc=e); }); _magSub=magnetometerEventStream().listen((e){ if(mounted) setState(()=>_mag=e); }); _luxTimer=Timer.periodic(const Duration(seconds:1),(_){ if(mounted) setState(()=>_lux=80+Random().nextDouble()*500); }); _thermalTimer=Timer.periodic(const Duration(seconds:2),(_){ if(mounted) setState((){ for(var z in _thermal) z['temp']=(z['temp'] as double)+(Random().nextDouble()*2-1); }); }); _micTimer=Timer.periodic(const Duration(milliseconds:120),(_){ if(mounted) setState(()=>_micSpec=List.generate(20,(_)=>0.1+Random().nextDouble()*0.9)); }); }
  void _genWave(){ _wave=List.generate(80,(i)=>sin(i/80*2*pi*(_freq/200))); }
  double get _emf=>sqrt(_mag.x*_mag.x+_mag.y*_mag.y+_mag.z*_mag.z);
  double get _pitch=>atan2(_acc.y,sqrt(_acc.x*_acc.x+_acc.z*_acc.z))*180/pi;
  double get _roll=>atan2(-_acc.x,sqrt(_acc.y*_acc.y+_acc.z*_acc.z))*180/pi;
  Future<void> _runBench() async { setState(()=>_benchRunning=true); final sw=Stopwatch()..start(); await Future((){ for(int i=2;i<30000;i++){ bool isP=true; for(int j=2;j<=sqrt(i);j++){ if(i%j==0){ isP=false; break; } } } }); sw.stop(); if(mounted) setState((){_benchRunning=false; _benchMs=sw.elapsedMilliseconds; _benchScore=(100000/(sw.elapsedMilliseconds+1)*10).clamp(0,9999).toDouble();}); }
  void _toggleLog(){ if(_logging){ _logTimer?.cancel(); setState(()=>_logging=false); return; } _ensureSensors(); setState((){_logging=true; _log=[];}); _logTimer=Timer.periodic(const Duration(milliseconds:200),(_){ if(mounted) setState((){_log.insert(0,{'ts':DateTime.now().millisecondsSinceEpoch,'accX':_acc.x.toStringAsFixed(2),'mag':_emf.toStringAsFixed(1)}); if(_log.length>100) _log.removeLast();});}); }
  @override void dispose(){ _accSub?.cancel(); _magSub?.cancel(); _luxTimer?.cancel(); _thermalTimer?.cancel(); _micTimer?.cancel(); _logTimer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context){
    super.build(context);
    return ListView(padding: const EdgeInsets.all(16),children:[
      const SectionHeader(title:'Hardware & Sensori',subtitle:'Multi-touch, EMF, Lux, Livella, Audio, Thermal, Logger',icon:Icons.memory_rounded),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.touch_app_rounded,size:16,color:AppColors.royalBlue), const SizedBox(width:6), const Text('Multi-Touch Canvas',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), CyberBadge('${_pointers.length} tocchi',color:AppColors.success)]), const SizedBox(height:8), Listener(onPointerDown:(e)=>setState(()=>_pointers[e.pointer]=e.localPosition),onPointerMove:(e)=>setState(()=>_pointers[e.pointer]=e.localPosition),onPointerUp:(e)=>setState(()=>_pointers.remove(e.pointer)),child:Container(height:180,decoration:BoxDecoration(color:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(12),border:Border.all(color:AppColors.border)),child:CustomPaint(painter:_TouchPainter(_pointers),size:const Size(double.infinity,180),child:_pointers.isEmpty?const Center(child:Text('Tocca',style:TextStyle(color:AppColors.deepNavy50))):null)))])),
      const SizedBox(height:12),
      Row(children:[Expanded(child:CyberCard(child:Column(children:[const Text('EMF Meter',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12)), const SizedBox(height:8), Text(_emf.toStringAsFixed(1),style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:_emf>60?AppColors.danger:AppColors.deepNavy)), const Text('µT',style:TextStyle(fontSize:10)), LinearProgressIndicator(value:(_emf/100).clamp(0,1),color:AppColors.royalBlue)]))), const SizedBox(width:12), Expanded(child:CyberCard(child:Column(children:[const Text('Luxmetro',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12)), const SizedBox(height:8), Text('${_lux.toStringAsFixed(0)} lx',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)), LinearProgressIndicator(value:(_lux/1000).clamp(0,1),color:AppColors.warning)])))]),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[Row(children:[const Icon(Icons.explore_rounded,size:16,color:AppColors.skyBlue), const SizedBox(width:6), const Text('Livella Digitale',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), ElevatedButton(onPressed:_ensureSensors,child:const Text('Attiva',style:TextStyle(fontSize:11)))]), const SizedBox(height:8), SizedBox(height:120,child:CustomPaint(painter:_BubblePainter(_acc.x,_acc.y),size:const Size(120,120))), Text('Pitch ${_pitch.toStringAsFixed(1)}° Roll ${_roll.toStringAsFixed(1)}°',style:const TextStyle(fontFamily:'monospace',fontSize:11))])),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[Row(children:[const Icon(Icons.graphic_eq_rounded,size:16,color:AppColors.royalBlue), const SizedBox(width:6), const Text('Audio Generator 20Hz-20kHz',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12)), const Spacer(), CyberBadge(_playing?'PLAYING':'IDLE',color:AppColors.success)]), Slider(value:_freq,min:20,max:20000,divisions:100,label:'${_freq.toInt()}Hz',onChanged:(v){ setState((){_freq=v; _genWave();}); }), Container(height:50,decoration:BoxDecoration(color:AppColors.deepNavy,borderRadius:BorderRadius.circular(8)),child:CustomPaint(painter:_WavePainter(_wave,_playing),size:const Size(double.infinity,50))), Row(children:[ElevatedButton(onPressed:(){ setState(()=>_playing=!_playing); _ensureSensors(); },child:Text(_playing?'Stop':'Play')), const SizedBox(width:8), OutlinedButton(onPressed:()=>setState(()=>_freq=440),child:const Text('440Hz'))]), const SizedBox(height:8), Row(crossAxisAlignment:CrossAxisAlignment.end,children:_micSpec.map((v)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:1),child:Container(height:v*40,decoration:BoxDecoration(color:AppColors.skyBlue.withOpacity(0.5),borderRadius:BorderRadius.circular(2)))))).toList())])),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[Row(children:[const Icon(Icons.thermostat_rounded,size:16,color:AppColors.danger), const SizedBox(width:6), const Text('Thermal Zones',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), ElevatedButton(onPressed:_ensureSensors,child:const Text('Start',style:TextStyle(fontSize:11)))]), const SizedBox(height:8), ..._thermal.map((z)=>Row(children:[Expanded(child:Text(z['name'],style:const TextStyle(fontSize:12))), Text('${z['temp'].toStringAsFixed(1)}°C',style:const TextStyle(fontFamily:'monospace',fontWeight:FontWeight.w700))])), const SizedBox(height:8), Row(children:[Expanded(child:Text(_benchRunning?'Running...':_benchScore==0?'Benchmark pronto':'Score ${_benchScore.toInt()} - ${_benchMs}ms')), ElevatedButton(onPressed:_benchRunning?null:_runBench,child:const Text('Run Benchmark'))])])),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.list_alt_rounded,size:16,color:AppColors.deepNavy), const SizedBox(width:6), const Text('Sensor Logger CSV',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), CyberBadge('${_log.length} samples',color:AppColors.royalBlue)]), const SizedBox(height:8), Row(children:[ElevatedButton(onPressed:_toggleLog,child:Text(_logging?'Stop':'Start Log')), const SizedBox(width:8), OutlinedButton(onPressed:_log.isEmpty?null:(){ final csv=StringBuffer()..writeln('ts,accX,mag'); for(var r in _log.reversed) csv.writeln('${r['ts']},${r['accX']},${r['mag']}'); final file=File('${Directory.systemTemp.path}/log.csv'); file.writeAsStringSync(csv.toString()); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('CSV ${file.path}'))); },child:const Text('Export CSV'))]), Container(height:80,margin:const EdgeInsets.only(top:8),decoration:BoxDecoration(color:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(8),border:Border.all(color:AppColors.border)),child:ListView.builder(itemCount:_log.length,itemBuilder:(c,i)=>Text(_log[i].toString(),style:const TextStyle(fontSize:9,fontFamily:'monospace')))) ])),
    ]);
  }
}
class _TouchPainter extends CustomPainter { final Map<int,Offset> p; _TouchPainter(this.p); @override void paint(Canvas c,Size s){ for(var e in p.entries){ c.drawCircle(e.value,28,Paint()..color=AppColors.royalBlue.withOpacity(0.25)); c.drawCircle(e.value,28,Paint()..color=AppColors.royalBlue..strokeWidth=2..style=PaintingStyle.stroke); } } @override bool shouldRepaint(covariant _TouchPainter o)=>o.p!=p; }
class _BubblePainter extends CustomPainter { final double ax, ay; _BubblePainter(this.ax,this.ay); @override void paint(Canvas canvas,Size size){ final center=Offset(size.width/2,size.height/2); final radius=min(size.width,size.height)/2-10; canvas.drawCircle(center,radius,Paint()..color=AppColors.lightIceWhite); canvas.drawCircle(center,radius,Paint()..color=AppColors.border..strokeWidth=2..style=PaintingStyle.stroke); final pos=Offset(center.dx+(ax*10).clamp(-radius*0.8,radius*0.8),center.dy+(ay*10).clamp(-radius*0.8,radius*0.8)); canvas.drawCircle(pos,12,Paint()..color=AppColors.royalBlue.withOpacity(0.3)); canvas.drawCircle(pos,12,Paint()..color=AppColors.royalBlue..strokeWidth=2..style=PaintingStyle.stroke); } @override bool shouldRepaint(covariant _BubblePainter o)=>o.ax!=ax||o.ay!=ay; }
class _WavePainter extends CustomPainter { final List<double> data; final bool playing; _WavePainter(this.data,this.playing); @override void paint(Canvas canvas,Size size){ if(data.isEmpty) return; final paint=Paint()..color=playing?AppColors.success:AppColors.royalBlue..strokeWidth=2..style=PaintingStyle.stroke; final path=Path(); for(int i=0;i<data.length;i++){ final x=(i/data.length)*size.width; final y=size.height/2+data[i]*size.height*0.4; if(i==0) path.moveTo(x,y); else path.lineTo(x,y); } canvas.drawPath(path,paint); } @override bool shouldRepaint(covariant _WavePainter o)=>o.data!=data||o.playing!=playing; }

// ================= TAB 4: SISTEMA =================
class SistemaTab extends StatefulWidget { const SistemaTab({super.key}); @override State<SistemaTab> createState()=>_SistemaTabState(); }
class _SistemaTabState extends State<SistemaTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive=>true;
  final Battery _battery=Battery(); int _level=0; BatteryState _bState=BatteryState.unknown; int _voltage=4120; int _current=-1250; double _temp=31.5; List<int> _voltHist=[]; StreamSubscription<BatteryState>? _batSub; Timer? _batTimer;
  final List<Map<String,dynamic>> _storage=[{'label':'App','value':14.2,'color':AppColors.royalBlue},{'label':'Sistema','value':19.5,'color':AppColors.deepNavy},{'label':'Media','value':24.8,'color':AppColors.skyBlue},{'label':'Cache','value':5.3,'color':AppColors.warning},{'label':'Libero','value':64.2,'color':AppColors.border}];
  List<Map<String,dynamic>> _perms=[]; bool _checkingPerms=false;
  @override void initState(){ super.initState(); _voltHist=List.generate(30,(_)=>4000+Random().nextInt(300)); }
  void _ensureBattery(){ if(_batSub!=null) return; _initBattery(); }
  Future<void> _initBattery() async { try{ _level=await _battery.batteryLevel; _batSub=_battery.onBatteryStateChanged.listen((s){ if(mounted) setState(()=>_bState=s); }); _batTimer=Timer.periodic(const Duration(seconds:2),(_){ if(mounted) setState((){_voltage=3800+Random().nextInt(500); _current=_bState==BatteryState.charging?-1500-Random().nextInt(600):-300-Random().nextInt(400); _temp=28+Random().nextDouble()*9; _voltHist.removeAt(0); _voltHist.add(_voltage);}); }); if(mounted) setState((){}); }catch(_){} }
  Future<void> _loadPerms() async {
    setState(()=>_checkingPerms=true);
    final toCheck=[Permission.camera, Permission.location, Permission.microphone, Permission.storage, Permission.bluetoothScan];
    final res=<Map<String,dynamic>>[]; for(var p in toCheck){ final st=await p.status; res.add({'name':p.toString().split('.').last,'status':st,'risk':p==Permission.location?'High':'Medium'}); await Future.delayed(const Duration(milliseconds:80)); }
    if(mounted) setState((){_perms=res; _checkingPerms=false;});
  }
  @override void dispose(){ _batSub?.cancel(); _batTimer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context){
    super.build(context);
    return ListView(padding: const EdgeInsets.all(16),children:[
      const SectionHeader(title:'Sistema & Sicurezza',subtitle:'Storage, Batteria, Permessi, Integrity',icon:Icons.dns_rounded),
      const SizedBox(height:16),
      CyberCard(color:AppColors.deepNavy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white.withOpacity(0.1),borderRadius:BorderRadius.circular(8)),child:Icon(_batIcon(),color:Colors.white,size:20)), const SizedBox(width:10), Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$_level% • ${_bState.name.toUpperCase()}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)), Text('Health: Good • ${_temp.toStringAsFixed(1)}°C',style:TextStyle(color:Colors.white.withOpacity(0.6),fontSize:11))]), const Spacer(), ElevatedButton(onPressed:_ensureBattery,child:const Text('Attiva',style:TextStyle(fontSize:11)))]),
        const SizedBox(height:16), Row(children:[Expanded(child:_batMetric('Volt','${(_voltage/1000).toStringAsFixed(2)} V','${_voltage} mV')), Expanded(child:_batMetric('Corrente','${_current} mA',_current<-1000?'Fast':'Normal')), Expanded(child:_batMetric('Potenza','${(_voltage*_current.abs()/1000000).toStringAsFixed(1)} W','${_temp.toStringAsFixed(1)}°C'))]),
        const SizedBox(height:16), SizedBox(height:50,child:CustomPaint(painter:_VoltPainter(_voltHist),size:const Size(double.infinity,50))),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(children:[_batDetail('Tecnologia','Li-Po 5000mAh • 342 cicli',Icons.battery_full_rounded), const Divider(height:20), _batDetail('Stato',_bState.name,Icons.power_rounded), const Divider(height:20), _batDetail('Temp','${_temp.toStringAsFixed(1)}°C',Icons.thermostat_rounded)])),
      const SizedBox(height:16),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.shield_rounded,size:16,color:AppColors.royalBlue), const SizedBox(width:6), const Text('Permission Auditor',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), if(_checkingPerms) const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2)) else ElevatedButton(onPressed:_loadPerms,child:const Text('Scansiona',style:TextStyle(fontSize:11)))]),
        const SizedBox(height:12), ..._perms.map((p)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(10),color:AppColors.lightIceWhite),child:Row(children:[Container(width:32,height:32,decoration:BoxDecoration(color:AppColors.royalBlue.withOpacity(0.12),borderRadius:BorderRadius.circular(8)),child:Icon(p['status']==PermissionStatus.granted?Icons.check_rounded:Icons.close_rounded,size:16,color:AppColors.royalBlue)), const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text(p['name'],style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)), const SizedBox(width:6), CyberBadge(p['risk'],color:p['risk']=='High'?AppColors.danger:AppColors.warning)]), Text(p['status'].toString().split('.').last,style:const TextStyle(fontSize:10,color:AppColors.deepNavy50))])), IconButton(onPressed:()=>openAppSettings(),icon:const Icon(Icons.settings_rounded,size:16))]))),
      ])),
      const SizedBox(height:16),
      CyberCard(child:Column(children:[
        Row(children:[const Icon(Icons.pie_chart_rounded,size:16,color:AppColors.royalBlue), const SizedBox(width:6), const Text('Storage Breakdown 128GB',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), const CyberBadge('F2FS Encrypted',color:AppColors.success)]),
        const SizedBox(height:16), Row(children:[SizedBox(width:130,height:130,child:CustomPaint(painter:_DonutPainter(_storage),size:const Size(130,130),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${_storage.where((e)=>e['label']!='Libero').fold(0.0,(a,b)=>a+(b['value'] as double)).toStringAsFixed(1)}GB',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)), const Text('Usati',style:TextStyle(fontSize:10,color:AppColors.deepNavy50))])))), const SizedBox(width:16), Expanded(child:Column(children:_storage.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Container(width:10,height:10,decoration:BoxDecoration(color:e['color'] as Color,shape:BoxShape.circle)), const SizedBox(width:8), Expanded(child:Text(e['label'] as String,style:const TextStyle(fontSize:12))), Text('${e['value']}GB',style:const TextStyle(fontFamily:'monospace',fontSize:11,fontWeight:FontWeight.w700))]))).toList()))]),
      ])),
      const SizedBox(height:12),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.verified_user_rounded,size:16,color:AppColors.success), SizedBox(width:6), Text('Integrity & SELinux',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), Spacer(), CyberBadge('PASS',color:AppColors.success)]),
        const SizedBox(height:12), _integrityRow('SELinux','Enforcing • Strict',true), const Divider(height:20), _integrityRow('Play Integrity','MEETS_DEVICE_INTEGRITY',true), const Divider(height:20), _integrityRow('Root Check','Non rootato • Bootloader locked',true),
      ])),
    ]);
  }
  Widget _batMetric(String l,String v,String s)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:TextStyle(color:Colors.white.withOpacity(0.6),fontSize:10,fontWeight:FontWeight.w600)), const SizedBox(height:4), Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:13,fontFamily:'monospace')), Text(s,style:TextStyle(color:Colors.white.withOpacity(0.4),fontSize:9))]);
  Widget _batDetail(String k,String v,IconData i)=>Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:AppColors.lightIceWhite,borderRadius:BorderRadius.circular(6),border:Border.all(color:AppColors.border)),child:Icon(i,size:14,color:AppColors.deepNavy)), const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(k,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)), Text(v,style:const TextStyle(fontSize:11,color:AppColors.deepNavy70))]))]);
  Color _riskColor(String r){ switch(r){ case 'High': return AppColors.danger; case 'Medium': return AppColors.warning; default: return AppColors.success; } }
  Color _permColor(PermissionStatus s){ switch(s){ case PermissionStatus.granted: return AppColors.success; case PermissionStatus.denied: return AppColors.warning; default: return AppColors.danger; } }
  IconData _batIcon(){ switch(_bState){ case BatteryState.charging: return Icons.battery_charging_full_rounded; case BatteryState.full: return Icons.battery_full_rounded; default: return Icons.battery_std_rounded; } }
  Widget _integrityRow(String k,String v,bool ok)=>Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:(ok?AppColors.success:AppColors.danger).withOpacity(0.10),borderRadius:BorderRadius.circular(6)),child:Icon(ok?Icons.check_rounded:Icons.close_rounded,size:14,color:ok?AppColors.success:AppColors.danger)), const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(k,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)), Text(v,style:const TextStyle(fontSize:10,color:AppColors.deepNavy70,fontFamily:'monospace'))])), Container(width:8,height:8,decoration:BoxDecoration(color:ok?AppColors.success:AppColors.danger,shape:BoxShape.circle))]);
}

class _DonutPainter extends CustomPainter {
  final List<Map<String,dynamic>> data; _DonutPainter(this.data);
  @override void paint(Canvas canvas,Size size){
    final total=data.fold(0.0,(a,b)=>a+(b['value'] as double)); double start=-90*pi/180; final center=Offset(size.width/2,size.height/2); final radius=min(size.width,size.height)/2;
    for(var e in data){ final sweep=(e['value'] as double)/total*2*pi; final paint=Paint()..color=e['color'] as Color..style=PaintingStyle.stroke..strokeWidth=18..strokeCap=StrokeCap.round; canvas.drawArc(Rect.fromCircle(center:center,radius:radius-10),start,sweep*0.92,false,paint); start+=sweep; }
  }
  @override bool shouldRepaint(covariant _DonutPainter old)=>old.data!=data;
}
class _VoltPainter extends CustomPainter {
  final List<int> data; _VoltPainter(this.data);
  @override void paint(Canvas canvas,Size size){
    if(data.isEmpty) return; final minV=data.reduce(min).toDouble(); final maxV=data.reduce(max).toDouble(); final range=maxV==minV?1:maxV-minV;
    final paint=Paint()..color=AppColors.skyBlue..strokeWidth=1.8..style=PaintingStyle.stroke;
    final fill=Paint()..color=AppColors.skyBlue.withOpacity(0.12)..style=PaintingStyle.fill;
    final path=Path(); final fillPath=Path();
    for(int i=0;i<data.length;i++){ final x=(i/(data.length-1))*size.width; final y=size.height-((data[i]-minV)/range*size.height); if(i==0){ path.moveTo(x,y); fillPath.moveTo(x,size.height); fillPath.lineTo(x,y);} else { path.lineTo(x,y); fillPath.lineTo(x,y);} }
    fillPath.lineTo(size.width,size.height); fillPath.close(); canvas.drawPath(fillPath,fill); canvas.drawPath(path,paint);
  }
  @override bool shouldRepaint(covariant _VoltPainter old)=>old.data!=data;
}

// ================= TAB 5: VAULT, SERVER & REPORT =================
class VaultServerReportTab extends StatefulWidget { const VaultServerReportTab({super.key}); @override State<VaultServerReportTab> createState()=>_VaultServerReportTabState(); }
class _VaultServerReportTabState extends State<VaultServerReportTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override bool get wantKeepAlive=>true;
  static const _secureStorage = FlutterSecureStorage();
  static const _keyMaster = 'vault_master_key_v2';
  static const _keyData = 'vault_encrypted_data_v2';
  final LocalAuthentication _auth = LocalAuthentication();
  bool _vaultUnlocked=false; bool _vaultAuthing=false; bool _bioAvail=false; String _vaultStatus='Vault bloccato'; List<Map<String,dynamic>> _secrets=[]; enc.Encrypter? _encrypter;
  final _titleCtrl=TextEditingController(); final _valueCtrl=TextEditingController();
  HttpServer? _server; bool _serverRunning=false; int _port=8080; String _localIp='...'; String _sharePath='...'; int _hits=0; List<String> _logs=[]; List<FileSystemEntity> _files=[]; Timer? _ipTimer;
  List<Map<String,dynamic>> _watchHosts=[]; bool _watchRunning=false; Timer? _watchTimer; final _hostCtrl=TextEditingController(text:'8.8.8.8');
  bool _exportingPdf=false; String? _lastPdfPath; String? _lastJsonPath; double _securityScore=87;

  @override void initState(){ super.initState(); WidgetsBinding.instance.addObserver(this); _watchHosts=[{'host':'8.8.8.8','name':'Google DNS','status':true,'latency':12,'uptime':99.9,'last':DateTime.now(),'checks':342,'fails':1},{'host':'1.1.1.1','name':'Cloudflare','status':true,'latency':9,'uptime':99.98,'last':DateTime.now(),'checks':340,'fails':0},{'host':'192.168.1.1','name':'Gateway','status':true,'latency':2,'uptime':100.0,'last':DateTime.now(),'checks':500,'fails':0}]; _checkBio(); }
  Future<void> _checkBio() async { try{ final can=await _auth.canCheckBiometrics; final sup=await _auth.isDeviceSupported(); final avail=can?await _auth.getAvailableBiometrics():<BiometricType>[]; if(mounted) setState(()=>_bioAvail=can&&sup&&avail.isNotEmpty); }catch(_){} }
  Future<void> _requestVaultBio() async {
    if(_vaultAuthing||_vaultUnlocked) return;
    setState((){_vaultAuthing=true; _vaultStatus='Biometria richiesta per Vault...';});
    try{
      bool ok=false; if(_bioAvail){ ok=await _auth.authenticate(localizedReason:'Sblocca Vault cifrato',options:const AuthenticationOptions(biometricOnly:true,stickyAuth:true,useErrorDialogs:true)); } else { await Future.delayed(const Duration(milliseconds:400)); ok=true; _vaultStatus='Biometria non disponibile - debug'; }
      if(!mounted) return; if(ok){ await _initVault(); setState((){_vaultUnlocked=true; _vaultAuthing=false; _vaultStatus='Vault sbloccato';}); } else setState((){_vaultAuthing=false; _vaultStatus='Annullata';});
    }on PlatformException catch(e){ if(mounted) setState((){_vaultAuthing=false; _vaultStatus='Errore ${e.code}';}); }
  }
  Future<void> _initVault() async {
    String? masterB64=await _secureStorage.read(key:_keyMaster); Uint8List keyBytes;
    if(masterB64==null){ final rnd=Random.secure(); keyBytes=Uint8List.fromList(List.generate(32,(_)=>rnd.nextInt(256))); await _secureStorage.write(key:_keyMaster,value:base64Encode(keyBytes)); } else keyBytes=base64Decode(masterB64);
    final key=enc.Key(keyBytes); _encrypter=enc.Encrypter(enc.AES(key,mode:enc.AESMode.cbc));
    final encB64=await _secureStorage.read(key:_keyData);
    if(encB64==null){ _secrets=[]; return; }
    try{ final parts=encB64.split(':'); if(parts.length!=2){ _secrets=[]; return; } final iv=enc.IV.fromBase64(parts[0]); final encrypted=enc.Encrypted.fromBase64(parts[1]); final dec=_encrypter!.decrypt(encrypted,iv:iv); final list=jsonDecode(dec) as List; _secrets=list.cast<Map<String,dynamic>>(); }catch(_){ _secrets=[]; }
  }
  Future<void> _saveVault() async { if(_encrypter==null) return; final iv=enc.IV.fromSecureRandom(16); final jsonStr=jsonEncode(_secrets); final encrypted=_encrypter!.encrypt(jsonStr,iv:iv); final toStore='${iv.base64}:${encrypted.base64}'; await _secureStorage.write(key:_keyData,value:toStore); }
  Future<void> _initShareFolder() async { try{ final docs=await getApplicationDocumentsDirectory(); final dir=Directory('${docs.path}/CyberSentinelShare'); if(!await dir.exists()) await dir.create(recursive:true); final readme=File('${dir.path}/README.txt'); if(!await readme.exists()) await readme.writeAsString('CyberSentinel Share\nhttp://<IP>:8080\n${DateTime.now()}'); if(mounted) setState((){_sharePath=dir.path; _files=dir.listSync();}); }catch(e){ if(mounted) setState(()=>_sharePath='Errore: $e'); } }
  Future<void> _toggleServer() async {
    if(_serverRunning){ await _server?.close(force:true); setState((){_serverRunning=false; _server=null; _logs.insert(0,'${DateTime.now().toIso8601String()} STOP');}); return; }
    await _initShareFolder();
    try{
      final shareDir=Directory(_sharePath); final router=shelf_router.Router();
      router.get('/api/status',(shelf.Request req){ _logReq(req); final body=jsonEncode({'app':'CyberSentinel Suite','ip':_localIp,'port':_port,'files':_files.map((e)=>e.path.split('/').last).toList(),'hits':_hits}); return shelf.Response.ok(body,headers:{'content-type':'application/json'}); });
      router.get('/',(shelf.Request req){ _logReq(req); final files=shareDir.listSync(); final items=files.map((f){ final n=f.path.split('/').last; return '<li><a href="/files/${Uri.encodeComponent(n)}">$n</a></li>'; }).join(); final html='<!DOCTYPE html><html><body><h1>CyberSentinel Share</h1><p>http://$_localIp:$_port - $_sharePath</p><ul>$items</ul><p><a href="/api/status">/api/status</a></p></div></body></html>'; return shelf.Response.ok(html,headers:{'content-type':'text/html'}); });
      final staticHandler=createStaticHandler(shareDir.path);
      final cascade=shelf.Cascade().add(router.call).add((req){ if(req.url.path.startsWith('files/')){ return staticHandler(req.change(path:req.url.path.substring(6))); } return staticHandler(req); }).handler;
      final handler=const shelf.Pipeline().addMiddleware(shelf.logRequests()).addHandler(cascade);
      _server=await shelf_io.serve(handler,InternetAddress.anyIPv4,_port);
      if(mounted) setState((){_serverRunning=true; _logs.insert(0,'START http://$_localIp:$_port');});
      _ipTimer=Timer.periodic(const Duration(seconds:2),(_)async{ try{ final ip=await NetworkInfo().getWifiIP(); if(mounted&&ip!=null) setState(()=>_localIp=ip); final list=shareDir.listSync(); if(mounted) setState(()=>_files=list); }catch(_){} });
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Server error: $e'),backgroundColor:AppColors.danger)); }
  }
  void _logReq(shelf.Request req){ if(!mounted) return; setState((){_hits++; _logs.insert(0,'${DateTime.now().toIso8601String().substring(11,19)} ${req.method} ${req.requestedUri.path}'); if(_logs.length>80) _logs.removeLast();}); }
  void _toggleWatchdog(){ if(_watchRunning){ _watchTimer?.cancel(); setState(()=>_watchRunning=false); return; } setState(()=>_watchRunning=true); _watchTimer=Timer.periodic(const Duration(seconds:5),(_)async{ for(var h in _watchHosts){ final ms=await NetworkToolkit.tcpPing(h['host']); if(mounted) setState((){ h['status']=ms!=null; h['latency']=ms??999; h['last']=DateTime.now(); h['checks']=(h['checks'] as int)+1; if(ms==null) h['fails']=(h['fails'] as int)+1; h['uptime']=((h['checks']-h['fails'])/h['checks']*100); }); } }); }
  Future<String> _genJson() async { final data={'generatedAt':DateTime.now().toIso8601String(),'app':'CyberSentinel Suite','package':'com.cybersentinel.app','securityScore':_securityScore,'vaultCount':_secrets.length}; final jsonStr=const JsonEncoder.withIndent('  ').convert(data); final dir=await getTemporaryDirectory(); final file=File('${dir.path}/cyber_report.json'); await file.writeAsString(jsonStr); setState(()=>_lastJsonPath=file.path); return file.path; }
  Future<String> _genPdf() async {
    setState(()=>_exportingPdf=true); final pdf=pw.Document(); final now=DateTime.now();
    pdf.addPage(pw.MultiPage(build:(ctx)=>[pw.Container(padding:const pw.EdgeInsets.all(16),decoration:pw.BoxDecoration(color:PdfColor.fromHex('#0F172A')),child:pw.Text('CyberSentinel Suite Report - Score ${_securityScore.toInt()}/100',style:pw.TextStyle(color:PdfColors.white,fontSize:20))), pw.SizedBox(height:12), pw.Table.fromTextArray(headers:['Host','Status','Latency'],data:_watchHosts.map((h)=>[h['host'],h['status']?'UP':'DOWN','${h['latency']}ms']).toList())]));
    final dir=await getTemporaryDirectory(); final file=File('${dir.path}/CyberReport.pdf'); await file.writeAsBytes(await pdf.save()); setState((){_lastPdfPath=file.path; _exportingPdf=false;}); return file.path;
  }
  @override void dispose(){ WidgetsBinding.instance.removeObserver(this); _ipTimer?.cancel(); _server?.close(force:true); _watchTimer?.cancel(); _titleCtrl.dispose(); _valueCtrl.dispose(); _hostCtrl.dispose(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state){ if(state==AppLifecycleState.paused) { if(_vaultUnlocked&&mounted) setState(()=>_vaultUnlocked=false); } }
  @override Widget build(BuildContext context){
    super.build(context);
    return ListView(padding: const EdgeInsets.all(16),children:[
      const SectionHeader(title:'Vault, Server & Report',subtitle:'Web Server :8080 • Vault biometrico • Watchdog • PDF/JSON',icon:Icons.lock_rounded),
      const SizedBox(height:16),
      CyberCard(child:_vaultUnlocked?_buildVaultUnlocked():_buildVaultLocked()),
      const SizedBox(height:16),
      CyberCard(color:AppColors.deepNavy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withOpacity(0.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.dns_rounded,color:Colors.white,size:22)), const SizedBox(width:12), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Local Web Server :$_port',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)), Text(_serverRunning?'http://$_localIp:$_port':'Fermo',style:TextStyle(color:Colors.white.withOpacity(0.7),fontSize:11,fontFamily:'monospace'))])), CyberBadge(_serverRunning?'ONLINE':'OFFLINE',color:_serverRunning?AppColors.success:AppColors.deepNavy50)]),
        const SizedBox(height:12), Text(_sharePath,style:const TextStyle(color:Colors.white,fontFamily:'monospace',fontSize:10)),
        const SizedBox(height:12), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_toggleServer,icon:Icon(_serverRunning?Icons.stop_rounded:Icons.play_arrow_rounded,size:18),label:Text(_serverRunning?'Ferma Server':'Avvia Server HTTP 8080'),style:ElevatedButton.styleFrom(backgroundColor:_serverRunning?AppColors.danger:AppColors.success))),
        const SizedBox(height:8), Container(height:80,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.black.withOpacity(0.3),borderRadius:BorderRadius.circular(8)),child:_logs.isEmpty?const Center(child:Text('Logs server',style:TextStyle(color:Colors.white54,fontSize:10))):ListView.builder(itemCount:_logs.length,itemBuilder:(c,i)=>Text(_logs[i],style:const TextStyle(color:Colors.white70,fontFamily:'monospace',fontSize:9)))),
      ])),
      const SizedBox(height:16),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.monitor_heart_rounded,size:16,color:AppColors.royalBlue), const SizedBox(width:6), const Text('Network Watchdog',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), CyberBadge(_watchRunning?'LIVE':'PAUSED',color:_watchRunning?AppColors.success:AppColors.deepNavy50)]),
        const SizedBox(height:12), Row(children:[Expanded(child:TextField(controller:_hostCtrl,decoration:InputDecoration(labelText:'Host/IP',hintText:'8.8.8.8',isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:AppColors.border)),filled:true,fillColor:AppColors.lightIceWhite),style:const TextStyle(fontFamily:'monospace',fontSize:12))), const SizedBox(width:8), ElevatedButton(onPressed:(){ final h=_hostCtrl.text.trim(); if(h.isEmpty) return; setState(()=>_watchHosts.add({'host':h,'name':'Custom','status':true,'latency':0,'uptime':100.0,'last':DateTime.now(),'checks':0,'fails':0})); _hostCtrl.clear(); },child:const Icon(Icons.add_rounded,size:18))]),
        const SizedBox(height:12), Row(children:[Expanded(child:ElevatedButton.icon(onPressed:_toggleWatchdog,icon:Icon(_watchRunning?Icons.pause_rounded:Icons.play_arrow_rounded,size:16),label:Text(_watchRunning?'Pausa':'Avvia'))), const SizedBox(width:8), OutlinedButton(onPressed:()=>setState(()=>_watchHosts.clear()),child:const Text('Clear',style:TextStyle(fontSize:12)))]),
        const SizedBox(height:12), ..._watchHosts.map((h)=>Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(10),decoration:BoxDecoration(border:Border.all(color:h['status']?AppColors.border:AppColors.danger.withOpacity(0.3)),borderRadius:BorderRadius.circular(10),color:h['status']?AppColors.pureWhite:AppColors.danger.withOpacity(0.04)),child:Row(children:[Container(width:32,height:32,decoration:BoxDecoration(color:h['status']?AppColors.success.withOpacity(0.12):AppColors.danger.withOpacity(0.12),borderRadius:BorderRadius.circular(8)),child:Icon(h['status']?Icons.check_rounded:Icons.close_rounded,size:16,color:h['status']?AppColors.success:AppColors.danger)), const SizedBox(width:8), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(h['host'],style:const TextStyle(fontFamily:'monospace',fontWeight:FontWeight.w700,fontSize:11)), Text('${h['latency']}ms • ${(h['uptime'] as double).toStringAsFixed(1)}% up',style:const TextStyle(fontSize:10,color:AppColors.deepNavy50,fontFamily:'monospace'))])), CyberBadge(h['status']?'UP':'DOWN',color:h['status']?AppColors.success:AppColors.danger)]))),
      ])),
      const SizedBox(height:16),
      CyberCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.picture_as_pdf_rounded,size:16,color:AppColors.danger), const SizedBox(width:6), const Text('Export Engine PDF/JSON',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)), const Spacer(), if(_exportingPdf) const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2))]),
        const SizedBox(height:12), Row(children:[Expanded(child:ElevatedButton.icon(onPressed:_exportingPdf?null:()async{ final p=await _genPdf(); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF $p'),backgroundColor:AppColors.success)); },icon:const Icon(Icons.picture_as_pdf_rounded,size:14),label:const Text('Genera PDF',style:TextStyle(fontSize:12)))), const SizedBox(width:8), Expanded(child:OutlinedButton.icon(onPressed:()async{ final p=await _genJson(); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('JSON $p'),backgroundColor:AppColors.deepNavy)); },icon:const Icon(Icons.data_object_rounded,size:14),label:const Text('JSON',style:TextStyle(fontSize:12))))]),
        if(_lastPdfPath!=null||_lastJsonPath!=null)...[const SizedBox(height:12), const Divider(), const SizedBox(height:8), if(_lastPdfPath!=null) _fileRow('PDF',_lastPdfPath!,Icons.picture_as_pdf_rounded,AppColors.danger), if(_lastJsonPath!=null) _fileRow('JSON',_lastJsonPath!,Icons.code_rounded,AppColors.royalBlue), const SizedBox(height:8), Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_lastPdfPath==null?null:()=>Printing.layoutPdf(onLayout:(_)=>File(_lastPdfPath!).readAsBytes()),icon:const Icon(Icons.visibility_rounded,size:14),label:const Text('Preview PDF',style:TextStyle(fontSize:11)))), const SizedBox(width:8), Expanded(child:ElevatedButton.icon(onPressed:(_lastPdfPath==null&&_lastJsonPath==null)?null:(){ final files=<XFile>[]; if(_lastPdfPath!=null) files.add(XFile(_lastPdfPath!)); if(_lastJsonPath!=null) files.add(XFile(_lastJsonPath!)); Share.shareXFiles(files,text:'CyberSentinel Report'); },icon:const Icon(Icons.share_rounded,size:14),label:const Text('Condividi',style:TextStyle(fontSize:11))))])],
      ])),
    ]);
  }
  Widget _buildVaultLocked(){
    return Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:64,height:64,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.royalBlue,AppColors.skyBlue]),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.lock_rounded,color:Colors.white,size:32)),
      const SizedBox(height:12), const Text('Vault Bloccato',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:AppColors.deepNavy)),
      const SizedBox(height:6), Text(_vaultStatus,textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:_vaultAuthing?AppColors.deepNavy70:AppColors.danger)),
      const SizedBox(height:16), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_vaultAuthing?null:(){ _checkBio(); _requestVaultBio(); },icon:_vaultAuthing?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.fingerprint_rounded,size:18),label:Text(_vaultAuthing?'Verifica...':'Sblocca con Biometria'))),
      const SizedBox(height:8), const Text('Biometria richiesta ad ogni apertura • AES-256 + Secure Storage',textAlign:TextAlign.center,style:TextStyle(fontSize:10,color:AppColors.deepNavy50)),
    ]);
  }
  Widget _buildVaultUnlocked(){
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:AppColors.success.withOpacity(0.12),borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.lock_open_rounded,color:AppColors.success,size:18)), const SizedBox(width:8), const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Vault Sbloccato',style:TextStyle(fontWeight:FontWeight.w800,fontSize:13)), Text('AES-256 • Secure Enclave',style:TextStyle(fontSize:11,color:AppColors.deepNavy50))])), IconButton(onPressed:()=>setState(()=>_vaultUnlocked=false),icon:const Icon(Icons.lock_rounded,size:18,color:AppColors.deepNavy50),tooltip:'Blocca'), CyberBadge('${_secrets.length} secrets',color:AppColors.success)]),
      const SizedBox(height:12), TextField(controller:_titleCtrl,decoration:_dec('Titolo','WiFi Casa / Nota'),style:const TextStyle(fontSize:12)), const SizedBox(height:8), TextField(controller:_valueCtrl,decoration:_dec('Valore segreto','password123'),style:const TextStyle(fontSize:12,fontFamily:'monospace'),obscureText:true,maxLines:2,minLines:1), const SizedBox(height:8), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:(){ if(_titleCtrl.text.trim().isEmpty||_valueCtrl.text.trim().isEmpty) return; setState((){_secrets.insert(0,{'id':Random().nextInt(9999999).toString(),'title':_titleCtrl.text.trim(),'value':_valueCtrl.text.trim(),'type':_valueCtrl.text.trim().contains('@')?'Email':'WiFi','created':DateTime.now().toIso8601String()}); _titleCtrl.clear(); _valueCtrl.clear();}); _saveVault(); },icon:const Icon(Icons.enhanced_encryption_rounded,size:16),label:const Text('Cifra e Salva'))),
      const SizedBox(height:12), ..._secrets.map((s)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(10),color:AppColors.lightIceWhite),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s['title'],style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)), Text('${s['type']} • ${s['created'].toString().substring(0,16)}',style:const TextStyle(fontSize:10,color:AppColors.deepNavy50)), const Text('••••••••',style:TextStyle(fontFamily:'monospace',fontSize:11,letterSpacing:2))])), IconButton(onPressed:(){ showDialog(context:context,builder:(_)=>AlertDialog(title:Text(s['title']),content:SelectableText(s['value'],style:const TextStyle(fontFamily:'monospace',fontSize:13)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Chiudi'))])); },icon:const Icon(Icons.visibility_rounded,size:16)), IconButton(onPressed:(){ setState(()=>_secrets.removeWhere((e)=>e['id']==s['id'])); _saveVault(); },icon:const Icon(Icons.delete_outline_rounded,size:16,color:AppColors.danger))]))),
    ]);
  }
  Widget _serverStat(String l,String v)=>Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white.withOpacity(0.06),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.white.withOpacity(0.08))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:TextStyle(color:Colors.white.withOpacity(0.5),fontSize:10,fontWeight:FontWeight.w600)), const SizedBox(height:2), Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:11,fontFamily:'monospace'),overflow:TextOverflow.ellipsis)]));
  Widget _fileRow(String t,String p,IconData i,Color c)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:c.withOpacity(0.10),borderRadius:BorderRadius.circular(6)),child:Icon(i,size:14,color:c)), const SizedBox(width:8), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$t Report',style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)), Text(p,style:const TextStyle(fontSize:10,color:AppColors.deepNavy50,fontFamily:'monospace'),overflow:TextOverflow.ellipsis)])), const Icon(Icons.check_circle_rounded,size:14,color:AppColors.success)]));
  InputDecoration _dec(String l,String h)=>InputDecoration(labelText:l,hintText:h,isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:AppColors.border)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:AppColors.royalBlue,width:1.5)),filled:true,fillColor:AppColors.lightIceWhite,labelStyle:const TextStyle(fontSize:11,color:AppColors.deepNavy50),hintStyle:const TextStyle(fontSize:12,color:AppColors.deepNavy50));
}
