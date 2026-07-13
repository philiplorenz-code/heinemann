---
name: checkout-startup-failure
description: Untersucht Startfehler des checkout-service
  im Namespace shop
---

## Ablauf
1. Pod-Status und Exit-Code prüfen.
2. Logs der vorherigen Containerinstanz lesen.
3. Deployment und eingebundene ConfigMaps untersuchen.
4. Erwartete Umgebungsvariablen mit den vorhandenen
   Schlüsseln vergleichen.
5. Ursache und Belege zusammenfassen.
