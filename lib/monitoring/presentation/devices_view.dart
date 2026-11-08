import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/language_service.dart';
import '../../shared/infrastructure/http_client.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../infrastructure/devices_api.dart';

/// Equivalente a `monitoring/presentation/devices.view.ts`.
/// (En el web los textos estaban fijos en español; aquí usan i18n.)
class DevicesView extends StatefulWidget {
  const DevicesView({super.key});

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  final _deviceId = TextEditingController();
  final _name = TextEditingController();
  bool submitting = false;
  String? error;
  bool copied = false;
  List<DeviceResponse> devices = [];
  DeviceRegistrationResponse? lastRegistered;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<DevicesApi>().list();
      if (mounted) setState(() => devices = d);
    } catch (_) {}
  }

  Future<void> register() async {
    if (submitting || _deviceId.text.trim().isEmpty) return;
    setState(() {
      submitting = true;
      error = null;
      copied = false;
    });
    try {
      final d = await context.read<DevicesApi>().register(_deviceId.text.trim(), _name.text.trim());
      _deviceId.clear();
      _name.clear();
      setState(() => lastRegistered = d);
      await _load();
    } catch (e) {
      setState(() => error = backendMessage(e) ?? context.trNow('devices.registerError'));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => copied = true);
    Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => copied = false) : null);
  }

  String initial(String? name) {
    final n = (name ?? '').trim();
    return n.isEmpty ? 'D' : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(FsSpace.s4),
      children: [
        PageHeader(
          eyebrow: context.tr('nav.devices'),
          title: context.tr('devices.title'),
          subtitle: context.tr('devices.subtitle'),
        ),
        FsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('devices.form.title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(context.tr('devices.form.hint'), style: const TextStyle(color: FsColors.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: _deviceId,
                decoration: InputDecoration(labelText: context.tr('devices.form.deviceId'), hintText: 'esp32-freshsense-1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: context.tr('devices.form.name'), hintText: 'Refrigerador cocina'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: FsColors.danger)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: submitting ? null : register,
                icon: const Icon(Icons.add),
                label: Text(context.tr(submitting ? 'devices.form.submitting' : 'devices.form.submit')),
              ),
              if (lastRegistered != null) ...[
                const SizedBox(height: 16),
                FsCard(
                  color: FsColors.successBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: FsColors.success),
                          const SizedBox(width: 8),
                          Text(context.tr('devices.pairing.title'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(context.tr('devices.pairing.hint'), style: const TextStyle(color: FsColors.textSecondary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              lastRegistered!.pairingCode,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => copyCode(lastRegistered!.pairingCode),
                            icon: const Icon(Icons.content_copy, size: 16),
                            label: Text(context.tr(copied ? 'devices.pairing.copied' : 'devices.pairing.copy')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${context.tr('devices.pairing.openEdge')} http://<ip-del-edge>:5000/edge/setup',
                        style: const TextStyle(color: FsColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FsSpace.s3),
        FsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('devices.list.title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (devices.isEmpty)
                EmptyState(icon: Icons.sensors, title: context.tr('devices.list.empty'))
              else
                for (final d in devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: FsColors.primaryLight,
                      child: Text(
                        initial(d.name ?? d.deviceId),
                        style: const TextStyle(color: FsColors.primaryDark, fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(d.name?.isNotEmpty == true ? d.name! : context.tr('devices.list.unnamed')),
                    subtitle: Text(d.deviceId),
                    trailing: FsBadge(context.tr('devices.list.registered'), status: FsStatus.ok),
                  ),
            ],
          ),
        ),
      ],
    ),
  );
}
