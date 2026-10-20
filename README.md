# Ghiozdane low-poly pentru Roblox

7 ghiozdane, de la cel mai slab la cel mai bun, construite din piese Roblox (Part / WedgePart / cilindri), fără mesh-uri externe:

| Tier | Nume | Rarity | Capacity* | Piese |
|---|---|---|---|---|
| 1 | Wooden Basket | Basic | 10 | 44 |
| 2 | Leather Pouch | Common | 20 | 13 |
| 3 | Canvas Bag | Uncommon | 35 | 11 |
| 4 | Explorer Pack | Rare | 60 | 18 |
| 5 | Reinforced Pack | Epic | 100 | 40 |
| 6 | Enchanted Satchel | Legendary | 175 | 20 + lumină + particule |
| 7 | Void Bag | Mythic | 300 | 34 + lumină + particule |

\* Valorile pentru Capacity sunt doar sugestii, salvate ca atribute. Le poți schimba în `BagBuilder.lua`.

![față](docs/preview-front.png)
![spate](docs/preview-back.png)

*Previzualizare randată în afara Roblox din aceleași date ale pieselor. În Studio, părțile Neon strălucesc, iar Enchanted Satchel și Void Bag au și PointLight și particule.*

## Instalare

1. **Generează modelele:** deschide Studio → View → Command Bar, lipește tot conținutul din `BagBuilder.lua` și apasă Enter.
   - Apar în `ReplicatedStorage.Bags` și într-un rând de preview în `Workspace.BagShowcase`. Pe acesta din urmă îl poți șterge.
   - Dacă rulezi scriptul din nou, modelele vechi sunt înlocuite.
2. **Pune ghiozdanul pe jucător (opțional):** pune `BagEquip.server.lua` ca Script în `ServerScriptService`. Apoi, din codul tău de upgrade:
   ```lua
   player:SetAttribute("EquippedBag", "Reinforced Pack")
   ```
   Ghiozdanul se schimbă imediat și rămâne și după respawn. Funcționează cu R15 și R6.

## Structura fiecărui model

- `PrimaryPart` = `Handle`: o piesă invizibilă cât corpul ghiozdanului. Toate celelalte piese sunt sudate de ea cu `WeldConstraint`.
- Fața **-Z** stă pe spatele personajului, iar fața **+Z** (buzunarele) e spre exterior.
- Atribute: `Tier`, `Capacity`, `Rarity`, `MountHeight` (cât de sus/jos stă pe spate, în studs; ajustează dacă avatarele tale au altă scară).
- Toate piesele au `CanCollide`, `CanTouch` și `CanQuery` = false, plus `Massless` = true, ca să nu afecteze mișcarea personajului.
