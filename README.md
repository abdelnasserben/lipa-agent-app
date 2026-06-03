# Lipa — Application mobile agent

Application Flutter du **portail agent Lipa** : dépôts/retraits d'espèces (cash-in /
cash-out), enrôlement de clients + KYC, vente et remplacement de cartes NFC,
commissions et relevés. L'UI reprend le design system du client Lipa (mêmes polices,
mêmes tokens) et consomme l'API décrite dans `Agent_Frontend_Specification.md` (v2.0),
qui fait **foi** : on n'appelle et n'affiche rien qui n'y figure pas.

> « KomoPay » est le nom interne du backend — jamais montré à l'opérateur. Toute la
> copie visible est en français, sous la marque **Lipa**. La devise est le **KMF**
> (entier, unité mineure).

## Stack

- **Flutter / Dart 3.12**
- **Riverpod** (`flutter_riverpod`) — état + injection de dépendances
- **Dio** — client HTTP (Bearer, refresh de token, `Idempotency-Key`,
  `X-Correlation-Id`, mapping d'erreurs)
- **flutter_secure_storage** — tokens dans le Keystore/Keychain
- **google_fonts** — Bricolage Grotesque (UI) + DM Mono (chiffres/codes)
- **nfc_manager** — lecture réelle de la puce NFC pour scanner les cartes ; repli en
  saisie manuelle de l'UID sur les téléphones sans NFC (abstrait derrière `core/scan`)
- **image_picker** — capture/sélection des pièces KYC (caméra + galerie)
- **pdf** / **printing** / **share_plus** — reçus & relevés (PDF généré localement,
  ouverture de la feuille d'impression/partage système)
- **intl**, **uuid**

## Architecture en couches

```
lib/
  core/            socle transverse
    config/        AppEnvironment / AppConfig (local|prod)
    auth/          TokenStore (stockage sécurisé)
    network/       ApiClient (Dio), enveloppes ApiResponse/PagedResponse
    error/         ApiError typée
    scan/          Scanner (seam NFC : puce réelle ↔ saisie manuelle de l'UID)
    theme/         tokens (couleurs, radius, ombres) + typographie
    utils/         formatters (KMF, téléphone, dates FR), reçu de transaction
    widgets/       widgets partagés (marque, champs, pills, PinSheet, écran résultat…)
    providers.dart DI : câble les repositories API
  data/
    models/        DTOs alignés sur la spec §7 + enums §9
    repositories/  AuthRepository + AgentRepository (interfaces + implémentations Dio)
  features/        présentation, par domaine
    auth/          login phone+PIN, MFA, session
    agent/         shell à 5 onglets (Accueil · Activité · Opérer · Cartes · Profil)
    home/          accueil : solde, résumé du jour, raccourcis
    operations/    hub « Opérer »
    cashin/ cashout/   dépôt / retrait d'espèces
    enroll/        enrôlement client + écran pièces KYC
    cards/         vente, recherche, remplacement, signalement perte/vol
    commissions/   suivi des commissions
    activity/      historique + détail transaction + relevé
    notifications/ inbox partagée (pull-only)
    profile/       profil + plafonds
    security/      enrôlement/révocation TOTP, changement de PIN
  app.dart         racine : bascule auth ↔ shell agent selon la session
  main.dart        point d'entrée
```

Les écrans ne contiennent **aucune donnée brute** : ils lisent des providers Riverpod
qui appellent les *repositories* (implémentations API sur Dio, dans `data/repositories/`).
Le `app.dart` n'a pas d'arbre d'URL (pas de GoRouter) : c'est un shell mono-acteur avec
navigation par onglet ; le seul branchement de haut niveau est auth vs. authentifié.

## Environnements (local / prod)

L'environnement est choisi au build via `--dart-define=ENV=...` (défaut : `local`) :

| ENV     | baseUrl par défaut       | Réseau ? |
|---------|--------------------------|----------|
| `local` | `http://10.0.2.2:8080`   | Oui — backend sur la machine de dev (alias émulateur Android pour le loopback hôte) |
| `prod`  | `https://api.lipa.km`    | Oui — API de production |

On peut surcharger l'URL : `--dart-define=API_BASE_URL=https://...`.

```bash
# Contre un backend local
flutter run --dart-define=ENV=local

# Build de production
flutter build apk --release --dart-define=ENV=prod
```

## Périmètre (conformité à la spec)

L'app couvre les **28 endpoints agent + 4 endpoints notifications** de la spec :

- **Auth agent** : login phone+PIN, MFA TOTP, cycle de vie du PIN
  (configuration via token `PIN_SETUP`, changement, reset self-service gated TOTP) ;
  access token TTL 8h → refresh proactif (~5 min avant expiration).
- **Profil / solde / plafonds / résumé du jour** — `/limits` en `404` traité comme
  « non configurés » (pas une erreur).
- **Cash-in** : dépôt sur le portefeuille client (lookup par téléphone).
- **Cash-out** avec la **boucle de contrôle** (spec §8) : resoumission avec le **même
  `Idempotency-Key`** plus `merchantPin` / `confirmationAcknowledged` ; branchement sur
  le statut HTTP, pas sur le corps.
- **Enrôlement client + KYC** : formulaire + upload multipart des pièces (caméra/galerie).
- **Cartes** : recherche (NFC ou UID manuel), vente, remplacement, signalement
  perte/vol ; suivi du stock de cartes.
- **Commissions** : liste paginée.
- **Activité** : transactions paginées + détail, relevé ; direction de transaction
  dérivée du `walletId` de l'agent.
- **Notifications** : inbox pull-only partagée, badge `/unread`, marquage lu.

Conventions transverses : `Idempotency-Key` (UUID) généré par intention financière et
conservé pendant la boucle de contrôle ; enveloppes `ApiResponse` / `PagedResponse`
parsées défensivement.

## Plateformes

Android + iOS sont scaffoldés. Android est la cible de dev/test. L'icône de lancement
réutilise le logo du client Lipa (`assets/icon/lipa_icon.png`) :

```bash
dart run flutter_launcher_icons   # régénère les icônes Android/iOS
```

## Vérification rapide

```bash
flutter analyze
flutter build apk --debug --dart-define=ENV=local
```
