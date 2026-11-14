# Azure-Tagging: Ressourcen finden und Vorgaben durchsetzen

Begleitcode zum IT-Administrator-Artikel „Wilde Ressourcen finden: Tagging-Strategien und Azure Policy zur Durchsetzung“.

Das Bicep-Lab erstellt drei Resource Groups und zwölf eigenständige Netzwerkressourcen. Absichtlich fehlerhafte Tags machen den Unterschied zwischen vorhandenen Werten, gültigen Werten und Policy-Compliance sichtbar. Es gibt keine VMs, Public IPs oder Datenlast.

## Aufbau

| Pfad | Inhalt |
| --- | --- |
| `bicep/` | Lab mit drei VNets, sechs NSGs, drei Route Tables und optionaler OwnerTeam-Audit-Policy |
| `scripts/lab.py` | Parameter erzeugen, What-if, Deployment, Abfragen und begrenzter Cleanup |
| `queries/lab.kql` | Sechs Resource-Graph-Abfragen mit Platzhaltern |
| `examples/required-tags.bicep` | Bicep-Ausschnitt mit verpflichtenden Tag-Parametern |
| `examples/terraform-required-tags/` | Vergleichbares Terraform-Beispiel; verwendet einen eigenen State |
| `examples/claranet/` | OpenTofu-Beispiel für das Claranet-Tagging-Modul |
| `examples/psrule/` | Eigene Pflicht-Tag-Prüfung mit PSRule |
| `tests/` | Lokale Prüfungen der Szenarien und Cleanup-Abgrenzung |

## Voraussetzungen

- Python 3.10+, Azure CLI mit Bicep sowie Resource-Graph-Erweiterung.
- Azure-Anmeldung und explizite Ziel-Subscription.
- Schreibrechte für die neuen Gruppen und Ressourcen; für die optionale Policy zusätzlich passende Policy-Rechte.
- Ein bereits vorhandener Network Watcher in der gewählten Region. Der Deployment-Helfer lehnt andere Regionen ab, damit Azure keinen Watcher außerhalb des Labs automatisch ergänzt.
- Bestehende organisationsweite Policies bleiben wirksam. Deny/Modify-Regeln können das beabsichtigte Fehlerbild verhindern oder ändern. Es werden keine Ausnahmen automatisch angelegt.

## Lab vorbereiten und bereitstellen

Alle Befehle laufen aus diesem Verzeichnis. Die Subscription-ID ist ein Platzhalter.

```bash
az login
az extension add --name resource-graph
python3 scripts/lab.py prepare --subscription <SUBSCRIPTION_ID> --location northeurope
python3 scripts/lab.py deploy
```

`prepare` arbeitet lokal, erzeugt eine neue LabId und schreibt die Parameter nach `.lab/`. `deploy` prüft vorhandene Gruppen, Policy-Namen und Network Watcher und speichert zunächst nur den What-if-Plan. Nach dessen Prüfung:

```bash
python3 scripts/lab.py deploy --execute
python3 scripts/lab.py inspect
```

Ohne Policy-Rechte kann bereits `prepare` die Option `--no-policy` erhalten. Der Helfer ändert den CLI-Default nicht; Azure-Aufrufe enthalten die Ziel-Subscription. `.lab/` enthält die lokalen IDs und Ergebnisse und gehört nicht ins Repository.

Die isolierte Demonstration ist nicht für Produktion gedacht. Beide Gruppen development und production sind leere Demo-Gruppen. Die Bezeichnungen bedeuten nicht, dass dort echte Anwendungen betrieben werden.

## Szenarien und erwartete Ergebnisse

Pro Gruppe gibt es ein VNet mit einem Subnetz, zwei NSGs und eine Route Table ohne Custom Routes. In development und production ist NSG 1 dem Subnetz zugeordnet. In legacy bleiben beide NSGs unzugeordnet. Keine Route Table besitzt eine Subnetzzuordnung.

| Gruppe | VNet | NSG 1 | NSG 2 | Route Table |
| --- | --- | --- | --- | --- |
| development | korrekt | Owner fehlt | CostCenter fehlt | Owner exakt leer |
| production | korrekt | Owner nur Leerzeichen | Environment=Production | CostCentre statt CostCenter |
| legacy | CostCenter=CC9999 | vollständig ungetaggt | Owner fehlt | korrekt |

Die absichtlich ungetaggte Ressource trägt auch kein LabId-Tag. Deshalb grenzen die Queries über Gruppen und Subscription ein.

Bei unverändertem Aufbau erwartet: zwölf Ressourcen, sieben mit fehlenden/leeren/Whitespace-Pflichtwerten, fünf mit vier nichtleeren Pflichtwerten und drei mit exakt modellkonformen Werten. Vier NSGs und drei Route Tables sind technisch unzugeordnet. Das ist keine Löschfreigabe und kein Nachweis einer Einsparung.

Die Audit-Regel prüft ausschließlich fehlendes oder exakt leeres OwnerTeam: acht Compliant, vier NonCompliant. Der Whitespace-Wert passiert die Regel bewusst. Anfangs leere Policy-State-Ergebnisse bedeuten „noch kein Ergebnis“, nicht „keine Verstöße“. Ein optionaler Scan lässt sich getrennt anstoßen; `inspect` schreibt nicht nach Azure und löst keinen Scan aus.

## Screenshots

1. Resource Graph Explorer: den letzten Block aus `.lab/queries.kql` einzeln ausführen. Zwölf Zeilen und die Owner-Spalte mit eckigen Klammern aufnehmen.
2. Policy / Compliance: die eigene Zuweisung in der production-Gruppe öffnen. Vier von vier Ressourcen sind zur engen OwnerTeam-Regel konform, obwohl die Inventartabelle Fehler zeigt.
3. Das [Azure Orphaned Resources Workbook](https://github.com/dolevshor/azure-orphan-resources) kann ergänzend importiert werden. Seine Portalansicht ist kein Bestandteil des Deployment-Helfers.

Im Artikel stammen die tatsächlichen Lab-Beobachtungen vom 13./14. November 2026. Das portable Paket verwendet denselben Bicep-Aufbau und dieselbe Szenariomatrix, erzeugt aber frische Namen und lokale IDs. Persönliche Nachweisdateien, Account-Informationen und Screenshots sind nicht Teil dieses Ordners. Neue Ausführungen müssen ihre eigenen tatsächlichen Ergebnisse kontrollieren.

## Weitere Beispiele

`required-tags.bicep` und `terraform-required-tags/` zeigen dasselbe fachliche Modell für eine Resource Group. Sie sind eigenständige Beispiele und werden nicht parallel auf das Bicep-Lab angewandt. Terraform verwendet die Anmeldung beziehungsweise `ARM_SUBSCRIPTION_ID`; keine IDs sind im Code hinterlegt. Bicep `minLength` verhindert keine reinen Leerzeichen. Die Terraform-Validierung prüft zusätzlich `trimspace`.

Das [Claranet-Modul](https://github.com/claranet/terraform-azurerm-tagging) ergänzt oder überschreibt Tags an expliziten Ressourcen-IDs. Die veröffentlichte Serie 9 setzt OpenTofu/AzureRM 5 voraus; seit Serie 8 prüft das Projekt HashiCorp-Terraform-Kompatibilität nicht mehr. Das Beispiel ist auf 9.0.0 begrenzt und benötigt die von upstream beschriebenen CLI-/Interpreter-Voraussetzungen. `merge` erhält fremde Schlüssel, kann aber gleichnamige Werte ändern. Nicht denselben Schlüssel gleichzeitig in einem zweiten Ressourcenmodul verwalten.

Die eigene [PSRule-Regel](https://azure.github.io/PSRule.Rules.Azure/customization/enforce-custom-tags/) wird zusammen mit `PSRule.Rules.Azure` verwendet. Im Ordner `examples/psrule/` müssen passende Resource-Group-Eingaben beziehungsweise Bicep-Expansion bereitstehen; die YAML-Datei bindet `type` und `resourceType`. Beispielaufruf nach Installation der Module:

```powershell
Assert-PSRule -Path '.ps-rule/' -Module 'PSRule.Rules.Azure' -InputPath . -Format File
```

Sie benötigt echte Eingaben; ein Lauf ohne geprüfte Ressourcen ist kein erfolgreicher Tagging-Test. PSRule prüft vorab, Azure Policy setzt Vorgaben am Azure-Scope durch.

## Kosten und Aufräumen

Leere VNets, NSGs und Route Tables ohne die ausgeschlossenen Zusatzdienste sollen keine zusätzlichen laufenden Verbrauchskosten erzeugen. Das ist kein hartes Kostenlimit. Region, Organisationsvorgaben und spätere Ergänzungen können die Situation ändern. `ExpiresOn` ist nur eine Erinnerung und löst nichts aus.

```bash
python3 scripts/lab.py cleanup --confirm-lab-id <LAB_ID>
python3 scripts/lab.py cleanup --confirm-lab-id <LAB_ID> --execute
```

Der erste Lauf prüft nur. Der zweite entfernt die eigenen Audit-Zuweisungen, die eigene Definition und genau die drei Lab-Gruppen. Er verweigert unerwartete oder fehlende Ressourcen, veränderte Ownership-Tags und zusätzliche lokale Policy-Zuweisungen. Er ist für den unveränderten Baseline-Aufbau gedacht. Nach zusätzlichen Deny-/Modify-/RBAC-/Remediation-Experimenten erfolgt ein manueller Abgleich vor jeder Löschung. Parallele Änderungen sind zu vermeiden; Azure-Operationen sind nicht atomar und ein Fehler kann Teilrückbau hinterlassen. Bestehender Network Watcher und Subscription-Deployment-Historie bleiben erhalten.

## Lokal prüfen

```bash
az bicep build --file bicep/main.bicep --outfile /tmp/tagging-lab.json
python3 -m unittest discover -s tests -v
```

Die portable Automation wurde lokal geprüft; der ursprüngliche Lab-Aufbau wurde in Azure beobachtet. Cleanup, Terraform, Community-Modul und PSRule sind nicht als live ausgeführt dokumentiert.
