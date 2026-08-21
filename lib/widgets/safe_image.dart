import 'package:flutter/material.dart';

class SafeImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeImage(this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorBuilder?.call(context, 'empty url', null) ?? 
             Container(
               width: width, 
               height: height, 
               color: Colors.grey[200], 
               child: const Icon(Icons.image_not_supported, color: Colors.grey)
             );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder ?? (context, error, stackTrace) => Container(
        width: width, 
        height: height, 
        color: Colors.grey[200], 
        child: const Icon(Icons.image_not_supported, color: Colors.grey)
      ),
    );
  }
}
