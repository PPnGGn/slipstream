/// Subtitle of the auto-connect row: what happens at launch right now.
String autoConnectSubtitle({required bool enabled}) => enabled
    ? 'Connects to the selected server when the app opens'
    : 'Off · tap the ring to connect';
