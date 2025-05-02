# 🗺️ App de Tacna para zonas peligrosas

Una aplicación móvil para ayudar a los usuarios a identificar zonas o rutas peligrosas en la ciudad de Tacna mediante varios factores. 
El proyecto utiliza **Flutter** para el desarrollo móvil y **Firebase** como backend (autenticación y base de datos).

----------

## 🔧 Funcionalidades Implementadas

 - [ ] Permitir crear cuenta de usuario e iniciar/cerrar sesión.
 - [ ] Botón de emergencia visible, con prevención de activaciones accidentales y opción de llamar a números locales (105, etc.).
 - [ ] Mostrar mapa interactivo de Tacna (Versión inicial).
 - [ ] Mostrar leyenda del mapa de calor.
 - [ ] Permitir ver detalles de riesgo al tocar una zona del mapa.
 - [ ] Permitir enviar reportes comunitarios con formulario (tipo, ubicación, hora, descripción).
 - [ ] Configuración de contactos de emergencia.
 - [ ] Mostrar marcadores temporales de incidentes recientes en el mapa.
 - [ ] Alternar entre mapa de calor y mapa normal con actualización automática.
 - [ ] Permitir al usuario ingresar origen y destino, calcular ruta priorizando seguridad y mostrarla visualmente en el mapa.
 - [ ] Permitir activar/desactivar notificaciones de riesgo y configurar sensibilidad/radio de alertas.
 - [ ] Enviar alerta de proximidad si las notificaciones están activadas.
 - [ ] Ofrecer alternativas de ruta (rápida vs segura).
 - [ ] Opción de emergencia para enviar SMS/Push a contactos de confianza
 - [ ] Gestionar configuraciones básicas (ej. activar/desactivar notificaciones).

    

----------

## 🧠 Estructura del Proyecto

----------

## 🔐 Firebase: Estructura Actual

Estamos utilizando Firebase para manejar la autenticación de usuarios. Aquí se describe brevemente la estructura de la base de datos (Firestore o Realtime Database, según el caso):

### 🔸 Autenticación

-   Proveedores: Email/Password
    
-   Campos mínimos: `email`, `password`, `displayName` (opcional)
    

### 🔸 Firestore (ejemplo si lo están usando)

Colección: `usuarios`

