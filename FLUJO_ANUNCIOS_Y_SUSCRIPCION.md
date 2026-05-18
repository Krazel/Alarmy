# Flujo de anuncios y suscripcion

Este flujo define el modelo reutilizable para todas las aplicaciones: anuncios muy poco invasivos, opcion de quitarlos con una suscripcion mensual tipo apoyo/donacion, y una forma central de desactivarlo por app.

## Objetivo

- Mantener las apps gratis.
- Mostrar anuncios solo cuando no molesten al uso principal.
- Permitir quitar anuncios con una suscripcion mensual de apoyo.
- Reutilizar el mismo patron en todas las apps.
- Poder apagar todo el sistema con un flag por aplicacion.

## Configuracion obligatoria por app

Cada app debe tener una configuracion central parecida a esta:

```swift
enum AppMonetizationConfig {
    static let adsEnabled = true
    static let supportPromptEnabled = true
    static let supportPromptIntervalDays = 14
    static let minimumMonthlySupport = "0,99 €"
}
```

Regla:
- Si `adsEnabled` es `false`, no se muestra ningun anuncio, no se muestra la seccion de suscripcion y no se muestra el recordatorio de apoyo.
- Si `adsEnabled` es `true`, se activa todo el flujo salvo que el usuario ya tenga suscripcion activa.

## Anuncios

Los anuncios deben ser lo menos invasivos posible:

- No interrumpir alarmas, grabaciones, escritura, juegos, meditaciones ni flujos criticos.
- No usar interstitials al abrir la app.
- No usar anuncios con sonido.
- No mover controles importantes cuando carga el anuncio.
- Preferir espacios pequenos y estables en pantallas secundarias.
- En una app de alarma, no mostrar anuncios en la pantalla de noche activa ni en la pantalla de alarma sonando.

Ubicaciones aceptables:
- Parte baja de pantallas de ajustes o listas.
- Despues de contenido, nunca antes de completar una accion.
- En pantallas informativas no criticas.

## Suscripcion de apoyo

La suscripcion mensual quita anuncios mientras este activa. El texto debe explicar que es una forma de apoyar el mantenimiento y la creacion de nuevas apps, sin bloquear funciones basicas.

Importes sugeridos:
- 0,99 € mensual
- 3 € mensual
- 5 € mensual
- 10 € mensual
- 15 € mensual
- 30 € mensual
- 50 € mensual
- 100 € mensual
- 300 € mensual

En iOS, estos importes deben ser productos de suscripcion configurados en App Store Connect y cargados con StoreKit. Apple muestra la hoja de pago del App Store y gestiona renovaciones, localizacion de precios y confirmacion de compra.

El importe manual solo se debe ofrecer en plataformas donde sea legal y tecnicamente viable. En iOS no debe depender de un campo libre para quitar anuncios; se usan productos fijos de In-App Purchase.

## Ajustes

Cada app con `adsEnabled = true` debe tener una seccion en Ajustes:

Titulo: `Apoyar la app`

Contenido:
- Estado: con anuncios / sin anuncios.
- Texto breve: `La app se mantiene gratis gracias a anuncios discretos y aportaciones mensuales.`
- Boton principal: `Quitar anuncios`
- Boton secundario: `Restaurar compras`

Si la suscripcion esta activa:
- Mostrar `Sin anuncios activo`.
- No mostrar recordatorios de apoyo.
- No cargar anuncios.

## Recordatorio cada dos semanas

Si `supportPromptEnabled = true`, `adsEnabled = true` y el usuario no tiene suscripcion activa:

- Al abrir la app, como maximo una vez cada 14 dias, mostrar un recordatorio.
- No mostrarlo durante una alarma, grabacion, sesion activa o flujo critico.
- El recordatorio debe tener salida clara: `Ahora no`.
- Debe permitir ir a Ajustes o a la pantalla de suscripcion.

Texto base:

> Usas esta app gratuitamente. La mantenemos con anuncios discretos y aportaciones mensuales. Si quieres aportar algo para que podamos seguir manteniendo esta app y crear nuevas, lo agradeceriamos.

## Implementacion StoreKit pendiente

Cuando se conecte StoreKit:

- Crear grupo de suscripcion mensual en App Store Connect.
- Crear un producto por importe.
- Usar StoreKit 2 para cargar productos, comprar, escuchar actualizaciones y restaurar compras.
- Guardar solo el estado derivado de transacciones verificadas.
- En revision de App Store, explicar donde se encuentra la pantalla de suscripcion.

Referencias oficiales:
- https://developer.apple.com/in-app-purchase/
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/
