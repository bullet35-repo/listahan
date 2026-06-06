import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _shimmerBox(height: 24, width: 200, color: color),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _shimmerCard(color)),
                      const SizedBox(width: 8),
                      Expanded(child: _shimmerCard(color)),
                      const SizedBox(width: 8),
                      Expanded(child: _shimmerCard(color)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _shimmerBox(height: 20, width: 150, color: color),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (_, index) => _shimmerOrderCard(color),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    required Color color,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3 + _animation.value * 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _shimmerCard(Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3 + _animation.value * 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _shimmerOrderCard(Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2 + _animation.value * 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(height: 18, width: 120, color: color),
              const Spacer(),
              _shimmerBox(height: 14, width: 80, color: color),
            ],
          ),
          const SizedBox(height: 12),
          _shimmerBox(height: 16, width: 100, color: color),
          const SizedBox(height: 12),
          Row(
            children: [
              _shimmerBox(height: 14, width: 60, color: color),
              const Spacer(),
              _shimmerBox(height: 14, width: 80, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
