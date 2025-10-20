# Dynamisches Ansible-Inventory mit NetBox

Dieses Beispiel zeigt, wie Sie Ansible direkt mit NetBox verbinden, um ein **dynamisches Inventory** zu erzeugen.

## Voraussetzungen
- funktionierende NetBox-Instanz mit Geräten (Status *active*, Rolle, Primary IP)
- gültiger API-Token, z. B.   
```bash
export NETBOX_TOKEN="<API_TOKEN>"
```

## Installation der NetBox-Collection
```bash
ansible-galaxy collection install netbox.netbox
ansible-galaxy collection list | grep netbox
```
## Beispielkonfiguration
### ansible.cfg
```
[inventory]
enable_plugins = netbox.netbox.nb_inventory
```
### inventory.yaml
```yaml
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.philiplorenz.com
token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
validate_certs: false
group_by:
  - sites
  - device_roles
compose:
  ansible_host: primary_ip4.address
```

## Inventory testen
Alle Hosts und Variablen anzeigen:
```bash
ansible-inventory -i inventory.yml --list
```
Strukturierte Ansicht der Gruppen:
```bash
ansible-inventory -i inventory.yml --graph
```

Wenn alles korrekt eingerichtet ist, erscheinen hier automatisch alle Geräte aus NetBox – gruppiert nach Standort und Rolle, inklusive IPs und Metadaten.