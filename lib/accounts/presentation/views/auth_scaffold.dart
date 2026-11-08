import 'package:flutter/material.dart';

import '../../../core/i18n/language_service.dart';
import '../../../shared/presentation/theme/app_theme.dart';

/// Estructura común de login/registro: banner con imagen + formulario
/// (equivale a `.banner-section` + `.form-section` del web).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.tagline,
    required this.sub,
    required this.heading,
    required this.subtitle,
    required this.children,
  });

  final String tagline;
  final String sub;
  final String heading;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: FsColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/banneralimentos.jpg', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xCC0B3D22)],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(FsSpace.s5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: FsColors.primary,
                                  borderRadius: BorderRadius.circular(FsRadius.md),
                                ),
                                child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('app.brand'),
                                style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            tagline,
                            style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(sub, style: t.bodyMedium?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(FsSpace.s5, FsSpace.s6, FsSpace.s5, FsSpace.s8),
            sliver: SliverList.list(
              children: [
                Text(heading, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: t.bodyMedium?.copyWith(color: FsColors.textSecondary)),
                const SizedBox(height: FsSpace.s5),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo con etiqueta arriba (equivale a `.input-group`).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FsSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        _Field(
          controller: controller,
          hint: hint,
          obscure: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
        ),
      ],
    ),
  );
}

class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    this.hint,
    required this.obscure,
    this.keyboardType,
    required this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _hidden,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    autofillHints: widget.autofillHints,
    decoration: InputDecoration(
      hintText: widget.hint,
      suffixIcon: widget.obscure
          ? IconButton(
              icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hidden = !_hidden),
            )
          : null,
    ),
  );
}
