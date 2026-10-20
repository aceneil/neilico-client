// NEILICO 客户端主界面（Tailscale 风格布局）
//
// 纯布局实现：不依赖 flutter_hbb 的 bind/gFFI，方便单独预览与后续接入。
// 接入控制面后从 `/api/v1/nodes` 拉真实节点；未接入时保留 `_sampleDevices` 占位。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── 设计令牌 ────────────────────────────────────────────────────────────────
class _C {
  static const rail = Color(0xFF0A0F1A);
  static const bg = Color(0xFF0D1421);
  static const card = Color(0xFF131C2B);
  static const cardHover = Color(0xFF172233);
  static const border = Color(0xFF1E2A3E);
  static const text = Color(0xFFE6EDF7);
  static const muted = Color(0xFF8A9AB5);
  static const accent = Color(0xFF3B82F6);
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF64748B);
}

class _Device {
  const _Device({
    required this.name,
    required this.os,
    required this.ip,
    required this.online,
    this.detail = '',
    this.isThisDevice = false,
  });

  final String name;
  final String os;
  final String ip;
  final bool online;
  final String detail;
  final bool isThisDevice;
}

const _sampleDevices = <_Device>[
  _Device(
    name: 'neil-Kubuntu',
    os: 'Linux',
    ip: '100.64.0.2',
    online: true,
    detail: '本机 · 子网路由已启用',
    isThisDevice: true,
  ),
  _Device(
    name: 'NAS-E125',
    os: 'Linux',
    ip: '100.64.0.3',
    online: false,
    detail: '最后在线 12 天前',
  ),
  _Device(
    name: 'office-win11',
    os: 'Windows',
    ip: '100.64.0.7',
    online: true,
    detail: '远程桌面可用 · 24 ms',
  ),
];

class NeilicoHomePage extends StatefulWidget {
  const NeilicoHomePage({Key? key}) : super(key: key);

  @override
  State<NeilicoHomePage> createState() => _NeilicoHomePageState();
}

class _NeilicoHomePageState extends State<NeilicoHomePage> {
  bool _connected = false;
  bool _enrolled = false;
  int _railIndex = 0;
  String _query = '';
  String _serverBase = '';
  List<_Device> _devices = _sampleDevices;

  List<_Device> get _visible => _devices
      .where((d) => _query.isEmpty ||
          d.name.toLowerCase().contains(_query.toLowerCase()) ||
          d.ip.contains(_query))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('neilico_api_token') ?? '').trim();
    final base = (prefs.getString('neilico_server_base') ?? '').trim();
    if (token.isEmpty || base.isEmpty) {
      _applyNotEnrolled();
      return;
    }
    try {
      final response = await http
          .get(
            Uri.parse('$base/api/v1/nodes?page_size=50'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _applyNotEnrolled();
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] ?? const []) as List<dynamic>;
      final devices =
          items.whereType<Map<String, dynamic>>().map(_deviceFromNode).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
        _enrolled = true;
        _connected = true;
        _serverBase = base;
      });
    } catch (_) {
      _applyNotEnrolled();
    }
  }

  void _applyNotEnrolled() {
    if (!mounted) {
      return;
    }
    setState(() {
      _devices = _sampleDevices;
      _enrolled = false;
      _connected = false;
      _serverBase = '';
    });
  }

  _Device _deviceFromNode(Map<String, dynamic> node) {
    final name = (node['name'] ?? '').toString();
    final ip = (node['virtual_ip'] ?? '').toString();
    final online = (node['status'] ?? '').toString() == 'online';
    final lastSeen = node['last_seen'];
    var detail = online ? '在线' : '离线';
    if (!online && lastSeen != null) {
      final time = DateTime.tryParse(lastSeen.toString());
      if (time != null) {
        detail = '最后在线 ${_formatNodeTime(time)}';
      }
    }
    return _Device(
      name: name.isEmpty ? '未命名设备' : name,
      os: _osLabel((node['os'] ?? '').toString()),
      ip: ip,
      online: online,
      detail: detail,
    );
  }

  String _osLabel(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('windows')) {
      return 'Windows';
    }
    if (lower.contains('darwin') || lower.contains('macos')) {
      return 'macOS';
    }
    if (lower.contains('linux')) {
      return 'Linux';
    }
    return os.isEmpty ? '其他' : os;
  }

  String _formatNodeTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _buildRail(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1180;
                      final main = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusCard(),
                          const SizedBox(height: 22),
                          _buildDeviceSection(),
                        ],
                      );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: main),
                                    const SizedBox(width: 22),
                                    SizedBox(width: 300, child: _buildSideColumn()),
                                  ],
                                )
                              : main,
                        ),
                      );
                    },
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          const Text('NEILICO 0.4.0',
              style: TextStyle(color: _C.muted, fontSize: 11.5)),
          const SizedBox(width: 14),
          Container(width: 1, height: 12, color: _C.border),
          const SizedBox(width: 14),
          Text(_enrolled && _serverBase.isNotEmpty
              ? '控制面 $_serverBase'
              : '控制面 192.168.123.90:13000',
              style: const TextStyle(color: _C.muted, fontSize: 11.5)),
          const Spacer(),
          _dot(_connected),
          const SizedBox(width: 6),
          Text('最后同步 12 秒前',
              style: const TextStyle(color: _C.muted, fontSize: 11.5)),
        ],
      ),
    );
  }

  // ── 左侧导航 ──────────────────────────────────────────────────────────────
  Widget _buildRail() {
    return Container(
      width: 76,
      color: _C.rail,
      child: Column(
        children: [
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/neilico_icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0E),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _C.border),
                ),
                alignment: Alignment.center,
                child: const Text('N',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _railItem(Icons.lan_outlined, '设备', 0),
          _railItem(Icons.hub_outlined, '网络', 1),
          _railItem(Icons.dns_outlined, '路由', 2),
          const Spacer(),
          _railItem(Icons.settings_outlined, '设置', 3),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _railItem(IconData icon, String label, int index) {
    final active = _railIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _railIndex = index),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: active ? _C.accent.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: active ? _C.accent : _C.muted),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: active ? _C.accent : _C.muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 顶栏 ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          const Text('设备',
              style: TextStyle(
                  color: _C.text, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: (_connected ? _C.online : _C.offline).withOpacity(.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _enrolled ? (_connected ? '已连接' : '已断开') : '尚未接入',
              style: TextStyle(
                  color: _connected ? _C.online : _C.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: _C.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索设备名称或 IP',
                hintStyle: const TextStyle(color: _C.muted, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 17, color: _C.muted),
                filled: true,
                fillColor: _C.card,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加设备',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '账号',
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined,
                color: _C.muted, size: 22),
          ),
        ],
      ),
    );
  }

  // ── 这台设备 ──────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final self = _sampleDevices.firstWhere((d) => d.isThisDevice);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16233A), Color(0xFF131C2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _osBadge(self.os, 46),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(self.name,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _dot(_connected),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _pill('本机'),
                const SizedBox(width: 8),
                _pill(self.ip, mono: true),
                const SizedBox(width: 8),
                _pill(_enrolled ? '远程桌面可用' : '尚未接入',
                    color: _enrolled && _connected ? _C.online : _C.muted),
              ]),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_enrolled ? (_connected ? '已连接' : '未连接') : '尚未接入',
                  style: TextStyle(
                      color: _enrolled && _connected ? _C.online : _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('WireGuard · 100.64.0.0/10',
                  style: const TextStyle(color: _C.muted, fontSize: 11.5)),
            ],
          ),
          const SizedBox(width: 14),
          Switch(
            value: _connected,
            onChanged:
                _enrolled ? (v) => setState(() => _connected = v) : null,
            activeColor: Colors.white,
            activeTrackColor: _C.online,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _C.offline,
          ),
        ],
      ),
    );
  }


  // ── 右侧信息栏 ────────────────────────────────────────────────────────────
  Widget _buildSideColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideCard(
          title: '网络',
          children: [
            _kv('名称', 'default'),
            _kv('网段', '100.64.0.0/10', mono: true),
            _kv('成员', '3 台'),
            _kv('控制面', '192.168.123.90:13000', mono: true),
          ],
        ),
        const SizedBox(height: 16),
        _sideCard(
          title: '子网路由',
          children: [
            _routeRow('192.168.123.0/24', 'neil-Kubuntu', true),
            _routeRow('192.168.1.0/24', 'office-win11', true),
          ],
        ),
        const SizedBox(height: 16),
        _sideCard(
          title: '快捷操作',
          children: [
            _actionRow(Icons.copy_all_outlined, '复制本机 IP'),
            _actionRow(Icons.desktop_windows_outlined, '打开远程桌面'),
            _actionRow(Icons.monitor_heart_outlined, '网络诊断'),
          ],
        ),
      ],
    );
  }

  Widget _sideCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _C.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(k,
                style: const TextStyle(color: _C.muted, fontSize: 12)),
          ),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _C.text,
                  fontSize: 12,
                  fontFeatures:
                      mono ? const [FontFeature.tabularFigures()] : null,
                )),
          ),
        ],
      ),
    );
  }

  Widget _routeRow(String cidr, String owner, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _dot(active),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cidr,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()])),
                Text(owner,
                    style: const TextStyle(color: _C.muted, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: _C.muted),
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _C.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _C.text, fontSize: 12.5)),
            ),
            const Icon(Icons.chevron_right, size: 16, color: _C.muted),
          ],
        ),
      ),
    );
  }

  // ── 设备列表 ──────────────────────────────────────────────────────────────
  Widget _buildDeviceSection() {
    final devices = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('网络中的设备',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.border),
              ),
              child: Text('${devices.length}',
                  style: const TextStyle(color: _C.muted, fontSize: 11.5)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _loadDevices(),
              icon: const Icon(Icons.refresh, size: 15, color: _C.muted),
              label: const Text('刷新',
                  style: TextStyle(color: _C.muted, fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < devices.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: _C.border),
                _deviceRow(devices[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _deviceRow(_Device d) {
    return InkWell(
      onTap: () {},
      hoverColor: _C.cardHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            _osBadge(d.os, 34),
            const SizedBox(width: 14),
            SizedBox(
              width: 210,
              child: Row(children: [
                Flexible(
                  child: Text(d.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                if (d.isThisDevice) ...[
                  const SizedBox(width: 7),
                  _pill('本机'),
                ],
              ]),
            ),
            SizedBox(
              width: 130,
              child: Text(d.ip,
                  style: const TextStyle(
                      color: _C.muted,
                      fontSize: 12.5,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
            Expanded(
              child: Text(d.detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 12.5)),
            ),
            _dot(d.online),
            const SizedBox(width: 7),
            SizedBox(
              width: 44,
              child: Text(d.online ? '在线' : '离线',
                  style: TextStyle(
                      color: d.online ? _C.online : _C.muted, fontSize: 12)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _C.muted),
          ],
        ),
      ),
    );
  }

  // ── 小组件 ────────────────────────────────────────────────────────────────
  Widget _dot(bool online) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: online ? _C.online : _C.offline,
          shape: BoxShape.circle,
          boxShadow: online
              ? [BoxShadow(color: _C.online.withOpacity(.45), blurRadius: 6)]
              : null,
        ),
      );

  Widget _pill(String text, {bool mono = false, Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (color ?? _C.muted).withOpacity(.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color ?? _C.muted,
                fontSize: 11,
                fontFeatures:
                    mono ? const [FontFeature.tabularFigures()] : null)),
      );

  Widget _osBadge(String os, double size) {
    final icon = switch (os) {
      'Windows' => Icons.desktop_windows_outlined,
      'macOS' => Icons.laptop_mac_outlined,
      'Linux' => Icons.terminal,
      _ => Icons.devices_other,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.rail,
        borderRadius: BorderRadius.circular(size * .26),
        border: Border.all(color: _C.border),
      ),
      child: Icon(icon, size: size * .5, color: _C.text),
    );
  }
}
