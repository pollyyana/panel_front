/// URL do backend Go (panel-api).
///
/// Android emulator: `http://10.0.2.2:8081`
/// Dispositivo físico: `http://IP_DA_MAQUINA:8081`
const String panelApiBaseUrl = String.fromEnvironment(
  'PANEL_API_URL',
  defaultValue: 'http://localhost:8081',
);
