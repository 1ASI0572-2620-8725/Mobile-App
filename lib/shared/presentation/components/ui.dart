import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Piezas visuales reutilizables: equivalen a las clases CSS globales del web
/// (`page-header`, `card`, `badge`, `empty-state`, `skeleton`, sparklines SVG).

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, this.eyebrow, required this.title, this.subtitle, this.actions = const []});

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Text(
              eyebrow!.toUpperCase(),
              style: t.labelSmall?.copyWith(color: FsColors.primary, fontWeight: FontWeight.w700, letterSpacing: .8),
            ),
          const SizedBox(height: 4),
          Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: t.bodyMedium?.copyWith(color: FsColors.textSecondary)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: FsSpace.s3),
            Wrap(spacing: FsSpace.s2, runSpacing: FsSpace.s2, children: actions),
          ],
        ],
      ),
    );
  }
}

class FsCard extends StatelessWidget {
  const FsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FsSpace.s4),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    shape: borderColor == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FsRadius.lg),
            side: BorderSide(color: borderColor!, width: 1.4),
          ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class FsBadge extends StatelessWidget {
  const FsBadge(this.label, {super.key, this.status = FsStatus.off, this.icon});

  final String label;
  final FsStatus status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: status.color), const SizedBox(width: 4)],
        Text(
          label,
          style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 10});
  final FsStatus status;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.action});

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FsSpace.s8, horizontal: FsSpace.s4),
    child: Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: FsColors.primaryLight,
          child: Icon(icon, color: FsColors.primary, size: 30),
        ),
        const SizedBox(height: FsSpace.s3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FsColors.textMuted),
          ),
        ],
        if (action != null) ...[const SizedBox(height: FsSpace.s4), action!],
      ],
    ),
  );
}

/// Bloque gris animado mientras carga (equivale a `.skeleton`).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 8});
  final double height;
  final double width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: .45, end: 1.0).animate(_c),
    child: Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(color: FsColors.border, borderRadius: BorderRadius.circular(widget.radius)),
    ),
  );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 84});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      count,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: FsSpace.s3),
        child: Skeleton(height: height, radius: FsRadius.lg),
      ),
    ),
  );
}

/// Línea de tendencia (equivale a los `<polyline>` SVG del web).
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.color = FsColors.primary, this.height = 48, this.min, this.max});

  final List<double> values;
  final Color color;
  final double height;
  final double? min;
  final double? max;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparkPainter(values, color, min, max)),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.minV, this.maxV);
  final List<double> values;
  final Color color;
  final double? minV;
  final double? maxV;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const pad = 4.0;
    final lo = minV ?? values.reduce((a, b) => a < b ? a : b);
    final hi = maxV ?? values.reduce((a, b) => a > b ? a : b);
    final range = (hi - lo) == 0 ? 1 : hi - lo;
    final step = values.length > 1 ? (size.width - pad * 2) / (values.length - 1) : 0.0;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = pad + i * step;
      final y = size.height - pad - ((values[i] - lo) / range) * (size.height - pad * 2);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    if (values.length == 1) path.lineTo(size.width - pad, size.height / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}

/// Selector compacto tipo "chip" para los filtros (reemplaza a los `<select>` del web).
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        items: items.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    ),
  );
}

/// Imagen de red con respaldo (equivale a `(error)="onImgError($event)"`).
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fallback, this.fit = BoxFit.cover});
  final String? url;
  final Widget? fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fb = fallback ?? const ColoredBox(color: FsColors.primaryLight);
    if (url == null || url!.trim().isEmpty) return fb;
    return Image.network(url!, fit: fit, errorBuilder: (_, _, _) => fb);
  }
}
