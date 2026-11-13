# HP Deskjet 2050 J510 sur macOS Apple Silicon

Ce dépôt privé contient le pilote HP Deskjet 2050 J510 (Inkjet9 2.17.0.01, Intel x86_64) et un script pour l’installer sur un Mac Apple Silicon. Le pilote provient des fichiers HP déjà installés et mis en staging localement ; ce dépôt n’est ni un pilote HP récent ni une solution officielle prise en charge par HP.

L’installeur HP officiel refuse les versions de macOS supérieures à 15. Le paquet HP 5.1.1 est incompatible avec les versions récentes de macOS. Ce dépôt réutilise le pilote Inkjet9 pour permettre l’impression USB malgré ces restrictions.

## Utilisation

1. Connectez la Deskjet en USB et allumez-la.
2. Depuis la racine du dépôt, lancez :

   ```sh
   ./install.sh
   ```

   Le script demande les droits administrateur via `sudo`. Il installe le pilote, crée ou met à jour la file `HP_Deskjet_2050_J510_series`, puis affiche l’état CUPS. Aucune page n’est imprimée par défaut.
3. Pour envoyer volontairement une page de test :

   ```sh
   ./install.sh --test
   ```

4. Pour désinstaller, lancez `./install.sh --uninstall` et saisissez `OUI` à la demande de confirmation. La file, les bundles de pilote fournis par ce dépôt et le PPD seront supprimés.

## Prérequis

- macOS sur Apple Silicon, imprimante connectée en USB et allumée.
- Bash, CUPS (`lp`, `lpadmin`, `lpinfo`, `lpstat`) et `rsync` disponibles.
- Rosetta 2. Le script la vérifie et tente de l’installer si nécessaire ; une autorisation macOS peut être demandée.
- Un compte administrateur pour les opérations `sudo`.

## Limites et avertissements

- **Impression uniquement** : le scanner et les autres fonctions ne sont pas pris en charge.
- Pilote HP ancien, Intel et non maintenu ; son fonctionnement peut cesser après une future mise à jour de macOS.
- Le script copie uniquement les sous-arbres du pilote et du PPD, jamais l’ensemble du système de fichiers vers `/Library`. Il modifie le propriétaire et les permissions dans `/Library/Printers/hp` pour satisfaire les contrôles de sécurité de CUPS.
- La désinstallation retire les sept frameworks HP livrés avec ce pilote. Si d’autres pilotes HP anciens les utilisent, ils pourraient être affectés.
- Les pilotes et composants HP sont propriétaires. Leur redistribution est soumise aux conditions HP.
- **DÉPÔT PRIVÉ UNIQUEMENT — ne pas rendre ce dépôt public et ne pas redistribuer les pilotes.**

## Dépannage

### CUPS indique « insecure permissions »

Le propriétaire et les permissions du pilote dans `/Library/Printers/hp` doivent être corrigés. Relancez `./install.sh` : il applique `root:wheel`, retire les permissions d’écriture au groupe et aux autres, puis rend les fichiers lisibles.

### Erreur `utimensat` ou restriction SIP avec rsync

Ne lancez pas `rsync -a` vers `/` ou vers l’ensemble de `/Library`. L’option archive tente notamment de préserver les dates de répertoires et peut échouer avec `utimensat` ou les protections SIP. Le script ne copie que les deux sous-arbres nécessaires avec `rsync -rlD --omit-dir-times --no-owner --no-group`.

### Aucune imprimante USB détectée

Vérifiez que l’imprimante est allumée, connectée directement en USB, puis relancez le script. Il recherche une URI `usb://HP/Deskjet` avec `lpinfo -v`.
