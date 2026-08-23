# Laboral EC

Aplicación Flutter para pequeños empleadores de Ecuador. Centraliza empleados, contratos, estimaciones de nómina, calculadoras laborales y finiquitos sobre Supabase.

## Estado actual

El MVP incluye:

- Registro e inicio de sesión con Supabase Auth.
- Acceso a calculadoras sin necesidad de crear una cuenta.
- Múltiples empresas por usuario y aislamiento con RLS.
- Registro de región laboral de la empresa para cálculos del décimo cuarto.
- Registro de empleados y contrato inicial.
- Historial salarial en Supabase.
- Dashboard por empresa.
- Vista previa de nómina mensual.
- Calculadoras independientes de IESS, décimo tercero, décimo cuarto, vacaciones, horas suplementarias/extraordinarias y costo de contratación.
- Calculadora pública de finiquito a partir de fechas, remuneración, causal y región.
- Finiquito simplificado para empleados registrados: reutiliza sueldo, fecha de ingreso y modalidad de décimos del contrato.
- Cálculo automático de sueldo pendiente, proporcionales de décimos, estimación de vacaciones, desahucio e indemnización por despido cuando corresponde.
- Guardado de borradores de finiquito con snapshot del cálculo.
- Esquema versionado para nómina, horas extra, vacaciones, finiquitos y recordatorios.
- Pruebas unitarias del motor laboral.

> Los cálculos son orientativos. Las vacaciones efectivamente pendientes, remuneraciones variables, contratos colectivos, regímenes especiales y particularidades jurídicas requieren datos o revisión adicional antes de realizar pagos o trámites oficiales.

## Requisitos

- Flutter 3.47 o compatible.
- Dart 3.13 o compatible.
- Android SDK configurado.
- Proyecto Supabase.

## Ejecutar

```powershell
flutter pub get
flutter run -d TU_DEVICE_ID `
  --dart-define=SUPABASE_URL=https://TU_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```

Nunca agregues una `service_role` o secret key a la aplicación móvil.

## Base de datos

Las migraciones están en `supabase/migrations/`.

El frontend espera las tablas base:

- `profiles`
- `companies`
- `employees`
- `contracts`
- `salary_history`
- `legal_sources`
- `legal_parameters`

Y la migración del MVP agrega/normaliza:

- `payroll_periods`
- `payroll_entries`
- `payroll_items`
- `overtime_records`
- `vacation_periods`
- `terminations`
- `settlements`
- `settlement_items`
- `reminders`

La región de `companies` usa `costa_insular` o `sierra_amazonia`.

## Pruebas

```powershell
flutter analyze
flutter test
```

## Estructura

```text
lib/
├── app/
├── core/
├── data/
├── domain/
└── features/
    ├── auth/
    ├── calculators/
    ├── company/
    ├── employees/
    └── home/
```

El motor laboral se mantiene separado de las pantallas para poder versionar reglas y reutilizarlo en Android, iOS y una futura versión web.
