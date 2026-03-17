```markdown
# EA10 - Expert Advisor pour MetaTrader 5

## Description
EA10 est un Expert Advisor (EA) avancé pour MetaTrader 5, conçu pour exploiter les cassures de la session asiatique sur le Forex. La stratégie combine une logique de cassure de range avec des filtres de tendance, de volatilité et de volume pour générer des signaux d'entrée. Elle intègre une gestion des risques robuste, incluant le calcul dynamique des lots, des protections contre le drawdown et une gestion multi-sessions.

## Stratégie de Trading
L'EA opère selon le principe suivant :
1.  **Identification du Range** : Calcule le plus haut (`rangeHigh`) et le plus bas (`rangeLow`) des bougies quotidiennes formées pendant la session asiatique (00:00 - 06:00 GMT).
2.  **Attente de la Cassure** : Surveille une cassure validée de ce range pendant la session de trading principale (à partir de 08:00 GMT).
3.  **Filtrage des Signaux** : Applique une série de filtres stricts (tendance H1, indicateurs, volume, news) avant d'envoyer un ordre.
4.  **Gestion de la Position** : Place des ordres stop avec un Stop Loss (SL) et un Take Profit (TP) calculés dynamiquement, et gère la sortie via trailing stop, fermeture avant événements ou objectifs atteints.

## Prérequis
*   Une plateforme **MetaTrader 5** à jour.
*   Un compte de trading chez un broker supportant le trading algorithmique.
*   Une connexion internet stable pour les cotations en temps réel.
*   Une connaissance de base de l'interface MetaTrader 5 et de la gestion des risques.

## Installation
1.  Téléchargez les fichiers de l'Expert Advisor (`EA10.ex5` et éventuellement `EA10.mq5`).
2.  Ouvrez le dossier de données de MetaTrader 5 :
    *   Via MT5 : **Fichier > Ouvrir le Dossier de données**.
    *   Naviguez jusqu'au sous-dossier `MQL5/Experts/`.
3.  Copiez le fichier `EA10.ex5` dans ce dossier `MQL5/Experts/`.
4.  Redémarrez MetaTrader 5 ou actualisez la liste des EAs dans le **Navigateur** (raccourci `Ctrl+N`).

## Utilisation
1.  **Graphique** : Attachez l'EA à un graphique du symbole souhaité (ex: `EURUSD`).
2.  **Timeframe** : L'EA est conçue pour fonctionner sur le **M15** (timeframe d'exécution défini en interne). L'analyse de tendance se fait sur H1 et le range sur D1.
3.  **Paramètres** : Configurez les paramètres d'entrée selon votre tolérance au risque et votre capital (voir section ci-dessous).
4.  **Activation** : Cochez "Autoriser le trading algorithmique" dans les paramètres communs de l'EA et assurez-vous que le bouton "Auto Trading" (en haut de la plateforme) est vert.
5.  **Surveillance** : L'EA journalise ses actions dans l'onglet **Experts** du Terminal. Surveillez-le régulièrement.

## Paramètres Configurables (Inputs)

### 1. Paramètres Généraux
*   `MagicNumber` : Identifiant unique pour les ordres de cet EA. Permet de les distinguer des autres positions manuelles ou d'autres EAs.
*   `MaxOpenTrades` : Nombre maximum de positions simultanées autorisées pour cet EA sur ce symbole. (Défaut : 1).
*   `AllowLong` / `AllowShort` : Active les signaux d'achat ou de vente.

### 2. Filtres de Session et Temps
*   `TradeStartHour` / `TradeEndHour` : Heures GMT de début et de fin de la session de trading active.
*   `TradeMonday` ... `TradeFriday` : Jours de la semaine où le trading est autorisé.
*   `FridayCloseHour` : Heure GMT du vendredi après laquelle toutes les positions sont fermées (si `WeekendClose` est activé).
*   `UseNewsFilter` : Active le filtre d'événements économiques à fort impact.
*   `NewsMinutesBefore` / `NewsMinutesAfter` : Fenêtre de temps (en minutes) autour d'une news pendant laquelle aucun nouvel ordre n'est passé.
*   `CloseOnHighImpact` : Si vrai, ferme toutes les positions avant une news à fort impact.

### 3. Filtres de Tendance et Indicateurs
*   `TrendEMAPeriod` : Période de la moyenne mobile exponentielle (EMA) utilisée pour définir la tendance sur H1. (Défaut : 200).
*   `UseADXFilter`, `ADXPeriod`, `ADXThreshold` : Filtre basé sur l'ADX pour ne trader qu'en présence de tendance.
*   `UseRSIFilter`, `RSIPeriod`, `RSIOverbought`, `RSIOversold` : Filtre basé sur le RSI pour éviter les zones de surachat/vente.
*   `UseATRFilter`, `MinATRPips`, `MaxATRPips` : Filtre sur la volatilité (ATR).
*   `UseBBFilter`, `BBPeriod`, `BBDeviation`, `Min_Width_Pips`, `Max_Width_Pips` : Filtre sur la largeur des Bandes de Bollinger.
*   `UseVolumeFilter`, `VolumePeriod`, `VolumeMultiplier` : Filtre sur le volume (volume courant > moyenne mobile du volume * multiplicateur).

### 4. Logique du Range et Entrée
*   `AsianSessionStart` / `AsianSessionEnd` : Heures GMT définissant la session asiatique pour le calcul du range.
*   `MinRangePips` / `MaxRangePips` : Taille minimale et maximale (en pips) du range asiatique pour qu'un trade soit valide.
*   `MarginPips` : Marge de sécurité (en pips) ajoutée au-dessus/au-dessous du range pour confirmer la cassure et placer le SL.
*   `Early_Break_Action` : Action si une cassure se produit avant `TradeStartHour` (0=Annuler ordres, 1=Ne rien faire).

### 5. Gestion du Risque et Money Management
*   `LotMethod` : Méthode de calcul des lots (0=% du capital, 1=Lot fixe).
*   `RiskPercent` : Pourcentage du capital (Equity) risqué par trade (si `LotMethod=0`).
*   `FixedLot` : Taille de lot fixe (si `LotMethod=1`).
*   `MinLot` / `MaxLot` : Bornes minimales et maximales pour la taille de lot calculée.
*   `MaxOrderRetries` : Nombre de tentatives en cas d'échec d'envoi d'ordre.

### 6. Sortie (Take Profit & Stop Loss)
*   `TP_Method` : Méthode de calcul du TP (0=Dynamique ATR, 1=Ratio R:R Fixe).
*   `ATR_TP_Mult` : Multiplicateur de l'ATR pour le TP dynamique (ex: ATR*3).
*   `RiskRewardRatio` : Ratio Risque/Récompense cible (si `TP_Method=1`).
*   `UseTrailingStop` : Active le trailing stop.
*   `Trail_Activation_PC` : Pourcentage du profit potentiel (TP) à atteindre avant d'activer le trailing stop.
*   `Trail_Step_Pips` : Pas de déplacement du trailing stop (en pips).
*   `UsePartialClose` : Active la fermeture partielle de la position.
*   `PartialCloseRR` : Niveau de profit (en multiple du risque initial) pour fermer une partie de la position.

### 7. Protections
*   `MaxDailyDDPercent` : Drawdown quotidien maximum (en % de l'equity de début de jour) avant arrêt du trading pour la journée.
*   `MaxTotalDDPercent` : Drawdown total maximum (en % du solde) avant désactivation complète de l'EA.
*   `AllowAddPosition` : Autorise l'ajout de positions (pyramiding) si la première position est en profit.
*   `AddPositionRR` : Niveau de profit (en multiple du risque initial) requis pour ajouter une position.

## Avertissement sur les Risques
**LE TRADING SUR MARCHÉS FINANCIERS IMPLIQUE DES RISQUES ÉLEVÉS DE PERTE.** Cet Expert Advisor est un outil logiciel. Son passé, simulé ou réel, ne garantit en aucun cas ses performances futures.

*   **Testez rigoureusement** l'EA en backtest et sur un compte de démonstration avant toute utilisation en conditions réelles.
*   **Comprenez parfaitement** la logique de la stratégie et tous les paramètres.
*   **Adaptez la gestion des risques** (`RiskPercent`, `MaxDailyDDPercent`) à votre propre capital et tolérance au risque. Il est recommandé de ne jamais risquer plus de 1-2% de votre capital par trade.
*   **Surveillez activement** l'EA, surtout lors de publications de news majeures ou de conditions de marché anormales (volatilité extrême, gaps).
*   L'auteur/éditeur de cet EA décline toute responsabilité concernant les pertes financières encourues lors de son utilisation.

---
*Développé pour MetaTrader 5 - Utilisez à vos propres risques.*
```