# HolmesGPT Praxistest: Code-Beispiele

Code-Beispiele aus dem Artikel "Sherlock für den Cluster: Mit HolmesGPT Kubernetes-Störungen untersuchen".

## Voraussetzungen

- Kubernetes-Cluster mit konfiguriertem `kubectl`-Zugriff
- [Helm](https://helm.sh)
- Zugangsdaten zu einem unterstützten Modellanbieter (hier: OpenAI)

## Ablauf

| Schritt | Datei | Beschreibung |
| --- | --- | --- |
| 1 | `scripts/01-add-helm-repo.sh` | Robusta-Helm-Repository einbinden |
| 2 | `scripts/02-create-namespace-and-secret.sh` | Namespace `holmes` und Secret mit API-Schlüssel anlegen |
| 3 | `helm/values-basic.yaml` | Minimalkonfiguration: nur Kubernetes-Core und -Logs aktiv |
| 4 | `scripts/03-install-holmesgpt.sh` | HolmesGPT per Helm installieren |
| 5 | `scripts/04-verify-and-test.sh` | Installation prüfen und API testen |
| 6 | `manifests/checkout-broken.yaml` | Absichtlich fehlerhaftes Deployment für den Praxistest |
| 7 | `scripts/05-deploy-and-investigate.sh` | Fehlerhaften Workload ausrollen und über die HolmesGPT-API untersuchen |

## Skills

`skills/checkout-startup-failure/SKILL.md` zeigt einen eigenen Skill nach dem
[Agent-Skills-Format](https://github.com/anthropics/skills) für die Untersuchung
des Checkout-Service. `helm/values-custom-skill-snippet.yaml` zeigt, wie sich derselbe
Skill alternativ direkt in der Helm-Konfiguration hinterlegen lässt.

## Erweiterte Konfiguration

`helm/values-extended.yaml` erweitert `helm/values-basic.yaml` um Prometheus-Metriken,
eine direkte Loki-Anbindung und den Azure-MCP-Server (setzt ein AKS-Cluster mit
aktivierter Workload Identity voraus).

## Hinweis

Platzhalter wie `<CLIENT-ID>`, `<TENANT-ID>` und `<SUBSCRIPTION-ID>` müssen vor der
Verwendung durch echte Werte ersetzt werden. API-Schlüssel gehören nicht in Dateien,
sondern in Kubernetes Secrets bzw. Umgebungsvariablen (siehe `scripts/02-create-namespace-and-secret.sh`).
