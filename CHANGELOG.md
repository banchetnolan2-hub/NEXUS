# Journal des modifications

## 0.2.0 — V2 : construction et simulation jouables

### Ajouts
- **Simulation** déterministe à pas fixe (20 pas/s, ×1/×2/×4), indépendante de l'affichage
  (`simulation/`) : réseaux électriques (production/demande, manque d'énergie signalé),
  arbres mécaniques (rapports, surcharge qui ralentit le moteur), fluides (débit, réservoirs
  bornés), logique (capteur à hystérésis, interrupteur, porte ET/OU/NON).
- **10 machines fonctionnelles** : générateur, voyant lumineux, moteur, transmission,
  ventilateur, réservoir, pompe, interrupteur, capteur de niveau, porte logique.
- **Construction 3D** : caméra orbitale (souris + ZQSD/WASD), placement sur grille avec
  aperçu fantôme valide/invalide et raison affichée, rotation, sélection, glisser-déplacer,
  duplication, suppression, connexions par clic sur les ports (refus expliqués),
  annuler/rétablir.
- **Bibliothèque** : cartes avec miniatures 3D, recherche, filtres, aperçu des ports.
- **Inspecteur contextuel** généré depuis la définition de chaque machine : réglages réels,
  valeurs en direct, connexions (avec suppression), actions.
- **Nouvelle partie** : nom + atelier vide ou exemple fonctionnel.
- Aide des contrôles (F1), bulle d'aide contextuelle, barre d'état (simulation, temps,
  bilan énergétique).
- **Autotest intégré** au jeu exporté (`NEXUS.exe -- --selftest`).

### Modifications
- Sauvegardes : format 2 (machines, réglages, état des réservoirs, connexions, caméra),
  migration automatique des sauvegardes 0.1.
- Données utilisateur dans un dossier dédié : `%APPDATA%\NEXUS` (Windows).
- Export Windows avec icône et informations de version ; release vérifiée par l'autotest.
- HUD de l'atelier découpé en modules (`scenes/workshop/hud/`).

## 0.1.0 — Étape 1
Identité visuelle, design system, menu principal, paramètres, mise en page de l'atelier,
sauvegardes atomiques versionnées.
