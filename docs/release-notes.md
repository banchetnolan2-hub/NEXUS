Version Windows 64 bits de **NEXUS** — atelier de construction de machines.

### Installation
1. Téléchargez `NEXUS-…-windows-x64.zip` ci-dessous et décompressez-le où vous voulez.
2. Lancez **`NEXUS.exe`**. Aucune installation, ni Godot, ni connexion Internet ne sont nécessaires.

L'exécutable n'est pas signé : si Windows SmartScreen affiche « Windows a protégé votre ordinateur »,
cliquez sur **Informations complémentaires → Exécuter quand même**.

### Vos données
Sauvegardes et paramètres sont dans `%APPDATA%\NEXUS` (indépendant du dossier du jeu :
vous pouvez déplacer ou remplacer le dossier du jeu sans perdre vos parties).

### Configuration
Carte graphique compatible Vulkan conseillée. Sans Vulkan, lancez
`NEXUS.exe --rendering-method gl_compatibility`.

### Vérifier l'installation
`NEXUS.exe -- --selftest` exécute un autotest (ressources, paramètres, partie d'exemple,
sauvegarde et rechargement) et écrit un rapport dans `%APPDATA%\NEXUS\selftest\report.txt`.

Cet exécutable a passé cet autotest dans l'intégration continue (Windows émulé par Wine).
