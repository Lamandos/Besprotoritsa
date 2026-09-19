{{flutter_js}}
{{flutter_build_config}}

// Service-worker ownership belongs to service_worker.js, registered from
// index.html. This deliberately omits Flutter's retired generated worker.
// Keeping CanvasKit/SKWasm local makes the renderer available to that worker.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
