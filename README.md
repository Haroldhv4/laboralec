# Laboral EC

Aplicación Flutter para pequeños empleadores de Ecuador. Centraliza empleados, contratos, novedades laborales, nómina, obligaciones, calculadoras y finiquitos sobre Supabase.

## Estado actual

Laboral EC ya cubre el núcleo funcional del MVP:

- Registro e inicio de sesión con Supabase Auth.
- Calculadoras públicas sin necesidad de crear una cuenta.
- Menú lateral con perfil, navegación y cierre de sesión.
- Múltiples empresas por usuario y aislamiento con RLS.
- Región laboral por empresa (`costa_insular` / `sierra_amazonia`).
- Empleados, contrato inicial, sueldo, modalidad de décimos y fondo de reserva.
- Historial salarial.
- Dashboard operativo por empresa.
- Registro de horas suplementarias, extraordinarias y recargo nocturno por empleado.
- Registro de vacaciones tomadas por rango de fechas.
- Saldo estimado de vacaciones reutilizado en el finiquito.
- Nómina mensual persistente con sueldo proporcional, horas adicionales, IESS, décimos mensualizados, fondo de reserva y provisiones.
- Historial de periodos de nómina.
- Roles de pago en PDF para compartir desde el teléfono.
- Calculadoras independientes de IESS, décimo tercero, décimo cuarto, vacaciones, horas extra y costo de contratación.
- Calculadora pública de finiquito por fechas, remuneración, causal y región.
- Finiquito simplificado para empleados registrados reutilizando contrato, modalidad de décimos, región y vacaciones registradas.
- Cálculo automático de sueldo pendiente, décimos proporcionales, vacaciones, desahucio e indemnización cuando corresponda.
- Historial de finiquitos y desglose persistido por rubros.
- Obligaciones y recordatorios del empleador.
- Recordatorios automáticos al registrar empleados recientes y al guardar finiquitos.
- Motor laboral separado de la interfaz y cubierto por pruebas.
- CI en GitHub con `flutter analyze`, `flutter test` y compilación APK debug.

> Los cálculos son orientativos. Remuneraciones variables, saldos históricos no registrados, contratos colectivos, regímenes especiales y particularidades jurídicas requieren validación adicional antes de realizar pagos o trámites oficiales.

## Requisitos

- Flutter 3.47 o compatible.
- Dart 3.13 o compatible.
- Android SDK configurado.
- Proyecto Supabase.

## Ejecutar

```powershell
flutter pub get
flutter analyze
flutter test

flutter run -d TU_DEVICE_ID `
  --dart-define=SUPABASE_URL=https://TU_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```

Nunca agregues una `service_role` o secret key a la aplicación móvil.

## Base de datos

Las migraciones están versionadas en `supabase/migrations/`.

Tablas principales:

- `profiles`
- `companies`
- `employees`
- `contracts`
- `salary_history`
- `legal_sources`
- `legal_parameters`
- `payroll_periods`
- `payroll_entries`
- `payroll_items`
- `overtime_records`
- `vacation_periods`
- `terminations`
- `settlements`
- `settlement_items`
- `reminders`

Para el bloque operativo final aplica también:

```text
supabase/migrations/20260823040000_operational_completion.sql
```

Esta migración es idempotente y asegura `reminders`, RLS e índices usados por los nuevos flujos.

## Estructura

```text
lib/
├── app/
├── core/
├── data/
├── domain/
├── services/
├── widgets/
└── features/
    ├── auth/
    ├── calculators/
    ├── company/
    ├── employees/
    ├── home/
    ├── obligations/
    ├── payroll/
    ├── profile/
    └── settlements/
```

## Antes de publicar

El núcleo del producto ya es utilizable como MVP. Antes de una publicación comercial todavía corresponde una fase de release: validación legal/contable de casos de prueba, recuperación y eliminación de cuenta, política de privacidad y términos, analítica/crash reporting si se desea, pruebas en varios tamaños de pantalla, icono/splash/branding final y preparación de Play Store.

El motor laboral se mantiene separado de las pantallas para versionar reglas y reutilizarlo en Android, iOS y una futura versión web.
