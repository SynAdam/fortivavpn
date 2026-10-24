import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/ui/section_label.dart';

/// The custom DNS setting: what DNS is, and the two addresses the tunnel
/// uses when they are set. Empty fields keep the defaults.
class DnsSettingsScreen extends StatefulWidget {
  const DnsSettingsScreen({super.key});

  @override
  State<DnsSettingsScreen> createState() => _DnsSettingsScreenState();
}

class _DnsSettingsScreenState extends State<DnsSettingsScreen> {
  final _primaryDnsController = TextEditingController();
  final _secondaryDnsController = TextEditingController();
  bool _isLoading = true;

  // Keys used by the native VPN tunnel service
  static const _prefRemoteDns = 'pref_remote_dns';
  static const _prefDomesticDns =
      'pref_domestic_dns'; // Optional, but good to sync

  @override
  void initState() {
    super.initState();
    _loadDnsSettings();
  }

  @override
  void dispose() {
    _primaryDnsController.dispose();
    _secondaryDnsController.dispose();
    super.dispose();
  }

  Future<void> _loadDnsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final remoteDns = prefs.getString(_prefRemoteDns) ?? '';

    if (remoteDns.isNotEmpty) {
      final parts = remoteDns.split(',');
      if (parts.isNotEmpty) _primaryDnsController.text = parts[0].trim();
      if (parts.length > 1) _secondaryDnsController.text = parts[1].trim();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveDnsSettings() async {
    final l10n = S.of(context)!;
    final primary = _primaryDnsController.text.trim();
    final secondary = _secondaryDnsController.text.trim();

    if (primary.isNotEmpty && !_isValidIp(primary)) {
      _showError(l10n.invalidPrimaryDns);
      return;
    }
    if (secondary.isNotEmpty && !_isValidIp(secondary)) {
      _showError(l10n.invalidSecondaryDns);
      return;
    }

    final List<String> dnsList = [];
    if (primary.isNotEmpty) dnsList.add(primary);
    if (secondary.isNotEmpty) dnsList.add(secondary);

    final dnsString = dnsList.join(',');

    final prefs = await SharedPreferences.getInstance();

    if (dnsString.isEmpty) {
      await prefs.remove(_prefRemoteDns);
      await prefs.remove(_prefDomesticDns);
    } else {
      await prefs.setString(_prefRemoteDns, dnsString);
      await prefs.setString(_prefDomesticDns, dnsString);
    }

    if (mounted) {
      // The theme's snackbar: light text on a raised dark surface. The
      // check says it worked without a green bar under light text.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppDesign.protected,
                size: 18,
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(child: Text(l10n.dnsSaved)),
            ],
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppDesign.error,
              size: 18,
            ),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Text(
                message,
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppDesign.errorContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.dnsConfiguration),
        backgroundColor: AppDesign.appBarColor,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppDesign.steelLight),
            )
          : ListView(
              padding: AppDesign.clearOfNavBar(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              children: [
                // No hairline: the card is a step lighter than the canvas,
                // and an edge is only for equal surfaces (spec 2.3).
                Container(
                  padding: const EdgeInsets.all(AppDesign.space16),
                  decoration: BoxDecoration(
                    color: AppDesign.surfaceLow,
                    borderRadius: AppDesign.borderRadiusLarge,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppDesign.surfaceHigh,
                          borderRadius: AppDesign.borderRadiusSmall,
                        ),
                        // Outlined, as on the DNS row in Settings.
                        child: const Icon(
                          Icons.dns_outlined,
                          color: AppDesign.steelLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppDesign.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.whatIsDns,
                              style: text.titleSmall?.copyWith(
                                color: AppDesign.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppDesign.space6),
                            Text(l10n.dnsExplanation, style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesign.space24),
                SectionLabel(
                  l10n.configuration,
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDesign.space16,
                    bottom: AppDesign.space12,
                  ),
                ),
                _buildTextField(
                  controller: _primaryDnsController,
                  label: l10n.primaryDns,
                  hint: l10n.primaryDnsHint,
                ),
                const SizedBox(height: AppDesign.space16),
                _buildTextField(
                  controller: _secondaryDnsController,
                  label: l10n.secondaryDns,
                  hint: l10n.secondaryDnsHint,
                ),
                const SizedBox(height: AppDesign.space32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveDnsSettings,
                    child: Text(l10n.saveConfiguration),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    final text = AppDesign.textTheme;
    final shape = AppDesign.borderRadiusMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // On the line where the text inside the box starts.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppDesign.space16,
            bottom: AppDesign.space8,
          ),
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // An address is Latin machine text, typed and read left to right
        // in every language, as Check my IP shows it. It sits at the start
        // edge of the page, under its label, as the address there does:
        // on the right in a right to left language. The hint keeps the
        // same direction. Its words come first and its address after them
        // either way, so only where it sits changes.
        TextField(
          controller: controller,
          style: text.bodyLarge,
          textDirection: TextDirection.ltr,
          textAlign: Directionality.of(context) == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            hintTextDirection: TextDirection.ltr,
            hintStyle: text.bodyLarge?.copyWith(color: AppDesign.textTertiary),
            filled: true,
            fillColor: AppDesign.surfaceLow,
            border: OutlineInputBorder(
              borderRadius: shape,
              borderSide: const BorderSide(color: AppDesign.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: shape,
              borderSide: const BorderSide(color: AppDesign.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: shape,
              borderSide: const BorderSide(
                color: AppDesign.steelLight,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
