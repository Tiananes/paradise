import 'ai/provider_model.dart';
import 'models.dart';

/// Resolves the two generative side channels for one chat.
///
/// The rule everywhere is the one the model override already follows: a value
/// on the persona wins, an empty value follows the global setting, and a switch
/// that is null follows the global switch. Keeping the three-state rule in one
/// place is what stops the image tool and the speech tool from disagreeing
/// about which provider a half-configured character should use.
///
/// A half-configured pair (a provider with no model, or the reverse) is treated
/// as not configured at all rather than as a request to guess: guessing is how
/// a chat ends up quietly sending prompts to a model the user never picked.
class GenPrefs {
  const GenPrefs({
    required this.imageOn,
    required this.imageProviderId,
    required this.imageModelId,
    required this.imageSize,
    required this.ttsOn,
    required this.ttsEngine,
    required this.ttsProviderId,
    required this.ttsModelId,
    required this.ttsVoice,
    required this.ttsSpeed,
    required this.ttsAutoSpeak,
  });

  final bool imageOn;
  final String imageProviderId;
  final String imageModelId;
  final String imageSize;

  final bool ttsOn;
  final TtsEngine ttsEngine;
  final String ttsProviderId;
  final String ttsModelId;
  final String ttsVoice;
  final double ttsSpeed;

  /// Read finished replies out loud without being asked.
  final bool ttsAutoSpeak;

  /// True when there is an endpoint to talk to and a model to ask for.
  bool get imageReady => imageOn && imageProviderId.isNotEmpty && imageModelId.isNotEmpty;

  /// True when the endpoint engine is usable. The system engine needs nothing
  /// but the switch, so it is ready as soon as it is on.
  bool get ttsReady => ttsOn && (ttsEngine == TtsEngine.system || (ttsProviderId.isNotEmpty && ttsModelId.isNotEmpty));

  Provider? imageProvider(AiSettings settings) => imageProviderId.isEmpty ? null : findProvider(settings, imageProviderId);

  Provider? ttsProvider(AiSettings settings) => ttsProviderId.isEmpty ? null : findProvider(settings, ttsProviderId);
}

/// Builds the resolved view for [c] against the live settings.
///
/// The switches live on the persona and default to off; the global settings
/// only supply the endpoint to use once a persona asks for one. That split is
/// deliberate: "which voice" is a preference a user sets once, "may this
/// character talk" is a property of the character.
GenPrefs genPrefsFor(Chat c, AiSettings settings) {
  final p = c.persona;

  // persona first, then the global default; an empty string is "not set here"
  final imgProvider = p.imageProvider.trim().isNotEmpty ? p.imageProvider.trim() : settings.imageProviderId;
  final imgModel = p.imageModel.trim().isNotEmpty ? p.imageModel.trim() : settings.imageModelId;
  final imgSize = p.imageSize.trim().isNotEmpty ? p.imageSize.trim() : settings.imageSize;

  final voice = p.ttsVoice.trim().isNotEmpty ? p.ttsVoice.trim() : settings.ttsVoice;
  final ttsProvider = p.ttsProvider.trim().isNotEmpty ? p.ttsProvider.trim() : settings.ttsProviderId;
  final ttsModel = p.ttsModel.trim().isNotEmpty ? p.ttsModel.trim() : settings.ttsModelId;

  return GenPrefs(
    imageOn: p.imageEnabled,
    imageProviderId: imgProvider,
    imageModelId: imgModel,
    imageSize: imgSize.trim().isEmpty ? '1024x1024' : imgSize.trim(),
    ttsOn: p.ttsEnabled,
    ttsEngine: p.ttsEngine ?? settings.ttsEngine,
    ttsProviderId: ttsProvider,
    ttsModelId: ttsModel,
    ttsVoice: voice,
    ttsSpeed: settings.ttsSpeed,
    ttsAutoSpeak: p.ttsAutoSpeak,
  );
}

/// The line the model reads so it knows whether it can draw and speak.
///
/// Built from the resolved preferences rather than from the persona, so a role
/// that inherits a working global endpoint is told it can use it, and one whose
/// endpoint is missing is told to ask rather than to try and fail.
String genCapabilityBlock(GenPrefs prefs) {
  final lines = <String>[];
  if (prefs.imageReady) {
    lines.add('You can draw: call generate_image with a detailed english prompt.');
  }
  if (prefs.ttsReady) {
    lines.add(prefs.ttsEngine == TtsEngine.api
        ? 'You can speak: call speak to have a line read aloud in your own voice.'
        : 'You can speak: call speak to have a line read aloud by the device voice.');
  }
  if (lines.isEmpty) return '';
  return lines.join('\n');
}
