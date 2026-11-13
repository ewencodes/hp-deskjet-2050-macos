#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DRIVER_ROOT="$SCRIPT_DIR/drivers/Library/Printers"
readonly HP_SOURCE="$DRIVER_ROOT/hp"
readonly PPD_SOURCE="$DRIVER_ROOT/PPDs/Contents/Resources/HP Deskjet 2050 J510 series.ppd"
readonly HP_TARGET="/Library/Printers/hp"
readonly PPD_DIR="/Library/Printers/PPDs/Contents/Resources"
readonly PPD_TARGET="$PPD_DIR/HP Deskjet 2050 J510 series.ppd"
readonly QUEUE="HP_Deskjet_2050_J510_series"

TEST_PRINT=false
UNINSTALL=false

usage() {
  cat <<'USAGE'
Usage : ./install.sh [--test | --uninstall]

Sans option, installe ou met à jour le pilote et configure la file d’impression.
  --test       envoie une page de test après l’installation
  --uninstall  retire la file et les éléments du pilote installés par ce dépôt
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --test) TEST_PRINT=true ;;
    --uninstall) UNINSTALL=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Option inconnue : %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$TEST_PRINT" == true && "$UNINSTALL" == true ]]; then
  printf 'Les options --test et --uninstall ne peuvent pas être utilisées ensemble.\n' >&2
  exit 2
fi

if [[ "$UNINSTALL" == true ]]; then
  printf 'Cette opération supprime la file %s et les fichiers HP de ce pilote dans /Library.\n' "$QUEUE"
  printf 'Pour confirmer, saisissez exactement OUI : '
  read -r confirmation
  if [[ "$confirmation" != "OUI" ]]; then
    printf 'Désinstallation annulée.\n'
    exit 0
  fi

  if lpstat -p "$QUEUE" >/dev/null 2>&1; then
    sudo lpadmin -x "$QUEUE"
  else
    printf 'La file %s n’existe pas ; rien à supprimer côté CUPS.\n' "$QUEUE"
  fi

  sudo rm -rf -- \
    "$HP_TARGET/cups/Inkjet9.driver" \
    "$HP_TARGET/cups/filters/commandtohp.filter" \
    "$HP_TARGET/PDEs/PDE.plugin"

  for framework in \
    HPDM.framework \
    HPDeviceModel.framework \
    HPDeviceMonitoring.framework \
    HPDriverCore.framework \
    HPEventStoring.framework \
    HPSmartPrint.framework \
    Matterhorn.framework; do
    sudo rm -rf -- "$HP_TARGET/Frameworks/$framework"
  done

  sudo rm -f -- "$PPD_TARGET"
  printf 'Désinstallation terminée. État des files CUPS :\n'
  lpstat -p || true
  exit 0
fi

if [[ ! -d "$HP_SOURCE" || ! -f "$PPD_SOURCE" ]]; then
  printf 'Les fichiers du pilote sont introuvables dans %s/drivers.\n' "$SCRIPT_DIR" >&2
  exit 1
fi

if ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  printf 'Rosetta 2 est nécessaire pour ce pilote Intel. Installation de Rosetta…\n'
  softwareupdate --install-rosetta --agree-to-license
  if ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    printf 'Rosetta 2 n’est pas disponible après la tentative d’installation.\n' >&2
    exit 1
  fi
fi

printf 'Copie du pilote HP (les symlinks sont préservés ; aucune copie de / vers /Library).\n'
sudo mkdir -p "$HP_TARGET" "$PPD_DIR"
sudo rsync -rlD --omit-dir-times --no-owner --no-group "$HP_SOURCE/" "$HP_TARGET/"
sudo rsync -rlD --omit-dir-times --no-owner --no-group "$PPD_SOURCE" "$PPD_DIR/"

printf 'Correction du propriétaire et des permissions requises par CUPS…\n'
sudo chown -R root:wheel "$HP_TARGET"
sudo chown root:wheel "$PPD_TARGET"
sudo chmod -R go-w "$HP_TARGET"
sudo chmod -R a+rX "$HP_TARGET" "$PPD_TARGET"
sudo chmod a+x \
  "$HP_TARGET/cups/Inkjet9.driver/Contents/MacOS/Inkjet9" \
  "$HP_TARGET/cups/filters/commandtohp.filter"
sudo xattr -dr com.apple.quarantine "$HP_TARGET" || true

printf 'Recherche de l’imprimante USB HP Deskjet…\n'
URI_LINE="$(lpinfo -v | grep -i 'usb://HP/Deskjet' || true)"
if [[ -z "$URI_LINE" ]]; then
  printf 'Aucune URI USB HP Deskjet détectée. Vérifiez le câble et allumez l’imprimante.\n' >&2
  exit 1
fi
URI="$(printf '%s\n' "$URI_LINE" | sed -E 's/^[[:space:]]*[^[:space:]]+[[:space:]]+([^[:space:]]+).*/\1/')"

if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  printf 'Mise à jour de la file %s…\n' "$QUEUE"
  sudo lpadmin -p "$QUEUE" -P "$PPD_TARGET"
else
  printf 'Création de la file %s…\n' "$QUEUE"
  sudo lpadmin -p "$QUEUE" -E -v "$URI" -P "$PPD_TARGET"
fi

sudo cupsenable "$QUEUE"
sudo launchctl kickstart -k system/org.cups.cupsd

if [[ "$TEST_PRINT" == true ]]; then
  printf 'Envoi d’une page de test à %s…\n' "$QUEUE"
  printf 'Test d’impression HP Deskjet 2050 J510\n\nPilote Inkjet9 2.17.0.01\n' |
    lp -d "$QUEUE" -t 'Test HP Deskjet 2050 J510'
fi

printf 'Vérification finale de la file d’impression :\n'
lpstat -p
