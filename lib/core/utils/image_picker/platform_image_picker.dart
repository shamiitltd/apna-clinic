// Apna Clinic - Cross-Platform Image Picker Helper
// Seamlessly handles native HTML5 file selection on Web without platform channel registration errors,
// and delegates to FilePicker on native desktop/mobile platforms.

export 'platform_image_picker_stub.dart'
    if (dart.library.html) 'platform_image_picker_web.dart';
