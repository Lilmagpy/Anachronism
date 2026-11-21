# Art prompts for Gemini

Painted art to replace the game's hand-drawn placeholders. Each set has a **style block**: paste
it with every prompt of that set, word for word, so all the pictures match. After the first
picture of a set comes out the way you like, attach it to every later prompt with the words
*"Match the style of the attached image exactly."* That keeps the set consistent.

**Getting the pictures to me:** save each one under the filename given (PNG if possible), then
on GitHub open the repository, switch to the branch `claude/phase-2-3d`, go into the folder
`client/art/incoming/` (type it into "Add file → Upload files" if it does not exist yet), and
upload. Any number at a time is fine. Tell me when some are up and I will fit them in.

Do the sets in the order below: they are ordered by how much they will improve the game.

---

## 1. Portraits of rulers (the biggest improvement)

These replace the flat cartoon faces in the court screen, the chapter cards and the dialogue
boxes. **Size: 4:5 (portrait), at least 800 × 1000.**

**Style block (paste with every portrait):**

> Painted portrait for a historical strategy game, in the style of a richly coloured
> storybook illustration: confident brush strokes, warm golden-hour light from the upper
> left, soft painted shading, slightly stylised but realistic proportions, dignified and
> characterful (not cartoonish, not photographic). Head and shoulders, facing three-quarters
> to the viewer's left, centred, with the top of the head near the top of the frame and the
> shoulders filling the bottom. Historically accurate clothing, hair and jewellery for the
> period. Plain flat pale grey background (#D9D9D9) with nothing else behind the figure. No
> text, no letters, no frame, no border, no watermark.

**Subjects** (one picture each; the filename comes first):

| File | Prompt (after the style block) |
|---|---|
| `portrait_roman.png` | A Roman consul of the 3rd century BC, about 50, clean-shaven, short grey hair, stern and shrewd, white wool toga with a broad purple border. |
| `portrait_senator.png` | A Roman senator, about 60, clean-shaven and lined, thinning hair, white toga with a purple stripe, a gold senator's ring. |
| `portrait_legate.png` | A Roman general of the Republic, about 40, clean-shaven, short dark hair, bronze muscled cuirass, red general's cloak over one shoulder. |
| `portrait_punic.png` | A Carthaginian noble of 250 BC, about 45, dark curled beard, olive skin, dark eyes, long robe of Tyrian purple with gold embroidery, gold hoop earring, a small conical cap. |
| `portrait_greek.png` | A Greek statesman of Athens, about 50, full grey-streaked beard, curly hair, cream chiton with a himation draped over the left shoulder. |
| `portrait_hellenistic.png` | A Hellenistic king, successor of Alexander, about 40, clean-shaven, wavy hair, a white cloth diadem band tied around the head, purple chlamys cloak fastened with a gold brooch. |
| `portrait_philosopher.png` | A Greek philosopher, about 65, long white beard, bald crown, plain undyed himation, holding a papyrus scroll, thoughtful eyes. |
| `portrait_pharaoh.png` | An Egyptian pharaoh of the New Kingdom, about 30, striped blue-and-gold nemes headdress with a cobra on the brow, kohl-lined eyes, broad jewelled collar, false beard. |
| `portrait_kushite.png` | A king of Kush (Meroë), about 40, dark skin, close-fitting cap crown with two cobras on the brow, gold armlets, a red cord over the shoulders. |
| `portrait_assyrian.png` | An Assyrian king, about 45, long black beard in rows of tight curls, tall fez-shaped royal tiara with a point, fringed embroidered robe, heavy gold earrings. |
| `portrait_hittite.png` | A Hittite great king of 1275 BC, about 40, clean-shaven, long hair, close skullcap, long robe and a curved staff over the shoulder. |
| `portrait_near_east.png` | A Persian noble of the Achaemenid court, about 40, curled black beard, soft felt hood-cap, long sleeved robe in saffron and blue. |
| `portrait_vizier.png` | A royal minister of the ancient Near East, about 55, grey beard, white linen robe, a gold chain of office. |
| `portrait_court.png` | A king of a Warring States Chinese state, 4th century BC, about 40, thin moustache and small beard, black silk robe with red borders and wide sleeves, a black lacquered cap with a jade pin, solemn and calculating. |
| `portrait_minister.png` | A Chinese chancellor of the Qin state, about 50, long thin moustache, black hemp-and-silk official's robe, black lacquered official's cap, a writing brush in his hand. |
| `portrait_southern.png` | A king of the southern Chinese state of Chu or Yue, about 45, dark red-and-black patterned silk robe with dragon and phoenix embroidery, a tall plumed cap, a bronze sword hilt at the shoulder. |
| `portrait_hills.png` | A chief of a western hill people bordering China (Qiang or Rong), about 40, weathered face, braided hair, sheepskin coat, bronze plaques at the belt. |
| `portrait_steppe.png` | A Mongol khan of 1206, about 45, wind-burnt face, long moustache, fur-trimmed conical hat, layered deel robe of blue silk and fur, a composite bow case at the shoulder. |
| `portrait_joseon.png` | A king of an early Korean kingdom (Goguryeo, 5th century), about 40, moustache, layered silk robe with patterned borders, a tall hat with bird-feather ornaments. |
| `portrait_samurai.png` | A Japanese daimyo of 1560, about 40, moustache, dark lacquered armour with orange silk lacing, kabuto helmet with a gold crest, a war fan. |
| `portrait_indian.png` | A Mauryan king of India, 3rd century BC, about 40, bare chest with heavy gold necklaces, a large white turban with a jewel, gold earrings, a white dhoti. |
| `portrait_south_asian.png` | A Gupta-era Indian prince, about 30, long dark hair, jewelled crown, pearl necklaces, red silk shawl. |
| `portrait_brahmin.png` | A brahmin priest of ancient India, about 60, shaved head with a tuft, white cloth, sacred thread across the chest, sandal-paste marks on the brow. |
| `portrait_turban.png` | A Persian shah of around AD 1000, about 45, black beard, large white silk turban with a jewelled plume, embroidered kaftan. |
| `portrait_berber.png` | A Berber (Numidian) king, about 40, dark curled hair and beard, white wool cloak, a gold fillet in the hair, a light javelin over the shoulder. |
| `portrait_celtic.png` | A Celtic chieftain of Gaul, about 35, long limed hair, long drooping moustache, a heavy gold torc at the neck, a checked wool cloak. |
| `portrait_viking.png` | A Norse jarl of around AD 1000, about 40, braided beard, fur cloak over a mail shirt, a silver Thor's-hammer amulet. |
| `portrait_rus.png` | A prince of Kievan Rus', about 40, full beard, fur-trimmed round cap, red brocade kaftan with a gold-buttoned front. |
| `portrait_byzantine.png` | A Byzantine emperor of around AD 1000, about 50, dark beard, a jewelled gold crown with hanging pearl strings, a jewelled gold loros sash over purple silk. |
| `portrait_medieval_king.png` | A European king of around AD 1000, about 45, short beard, gold crown, ermine-lined red mantle. |
| `portrait_knight.png` | A Norman knight, about 35, clean-shaven, mail coif pushed back, conical helmet with nasal guard under the arm, white surcoat. |
| `portrait_doge.png` | The Doge of Venice, about 65, white beard, the horn-shaped ducal cap (corno ducale) of gold brocade, an ermine shoulder cape. |
| `portrait_bishop.png` | A medieval bishop, about 60, clean-shaven, a white mitre with gold bands, an embroidered cope, a crozier at the shoulder. |
| `portrait_monk.png` | A Benedictine monk, about 50, tonsured, black habit, holding an illuminated book. |

**Advisers** (shown for every civilisation, so make them look of no particular nation):

| File | Prompt (after the style block) |
|---|---|
| `adviser_scholar.png` | A learned royal adviser, about 60, grey beard, simple dark scholar's robe, holding an open book of notes, kindly and sharp. |
| `adviser_steward.png` | A royal steward who keeps the stores, about 50, round and shrewd, a ring of keys and a wax tablet, plain good-quality robe. |
| `adviser_general.png` | A veteran general, about 50, scarred cheek, grey stubble, battered leather-and-bronze armour, a cloak over the shoulder. |
| `adviser_diviner.png` | A court diviner and astrologer, about 70, long white hair, robe with faint star patterns, holding a bronze astrolabe-like instrument, eyes looking upward. |

---

## 2. Chapter paintings for "Follow history"

A wide painting across the top of each chapter card. **Size: 16:9, at least 1600 × 900.**

**Style block:**

> Epic painted illustration for a historical strategy game, like a richly coloured
> storybook painting or a classic history-book plate: dramatic composition, warm and
> atmospheric light, painterly brushwork, historically accurate clothing, armour, ships and
> architecture for the date given. Wide cinematic framing with the main action in the
> middle third (the top and bottom edges may be cropped). No text, no letters, no frame, no
> border, no watermark.

| File | Prompt (after the style block) |
|---|---|
| `chapter_rome_messana.png` | 264 BC: Roman legionaries crossing the Strait of Messina at night in borrowed merchant boats, torches, the walls of Messana on the Sicilian shore ahead, moonlight on the water. |
| `chapter_rome_fleet.png` | 260 BC: Roman shipwrights on a beach building their first fleet of war galleys, copying a wrecked Carthaginian quinquereme, rowers practising on wooden benches set up on the sand. |
| `chapter_rome_cannae.png` | 216 BC, the battle of Cannae: a vast Roman army packed in a dense mass on a dusty plain, surrounded on all sides by Hannibal's Gauls, Spaniards and African infantry and Numidian horsemen, seen from a low hill, dust and summer heat. |
| `chapter_rome_archimedes.png` | 212 BC, Syracuse: Archimedes drawing geometric figures in sand on the floor of his courtyard, oblivious, while Roman soldiers burst in through a doorway behind him. |
| `chapter_rome_ad_portas.png` | 211 BC: Hannibal on horseback on a hill at dusk looking at the walls and temples of Rome three miles away, his army's campfires behind him, Romans crowding the walls. |
| `chapter_rome_zama.png` | 202 BC, the battle of Zama: Carthaginian war elephants charging through lanes left open in the Roman lines, trumpets blaring, Scipio on horseback in the distance. |
| `chapter_rome_fall_of_carthage.png` | 146 BC: Carthage burning at night, the great circular military harbour in the foreground, Scipio Aemilianus watching from a height and weeping. |
| `chapter_qin_xianyang.png` | 350 BC, the state of Qin, China: a crowd at the south gate of a rammed-earth city watching a peasant carry a long wooden log, an official holding up gold pieces, Shang Yang watching from a pavilion. |
| `chapter_qin_gongzi_ang.png` | 340 BC: a lacquered feast table in a Qin tent, two old friends raising wine cups, armed soldiers hidden behind painted screens in the background. |
| `chapter_qin_shu_or_han.png` | 316 BC: a Qin army marching single file along wooden plank roads bolted to the sheer cliffs of the Qinling mountains above a misty gorge. |
| `chapter_qin_changping.png` | 260 BC, the battle of Changping: two vast Chinese armies of the Warring States facing each other across fortified lines in a loess valley, crossbowmen, chariots and banners, autumn light. |
| `chapter_qin_dujiangyan.png` | 256 BC: thousands of workers building the Dujiangyan weir on the Min river, long bamboo baskets filled with stones, a fish-mouth-shaped island splitting the river, green mountains behind. |
| `chapter_qin_jing_ke.png` | 227 BC: the assassin Jing Ke lunging with a dagger in the Qin audience hall, the king pulling away behind a red lacquered pillar, a rolled map on the floor, courtiers frozen in shock. |
| `chapter_qin_all_under_heaven.png` | 221 BC: the First Emperor of Qin on a high terrace above a great palace courtyard, ranks of officials bowing, twelve giant bronze statues, banners of black. |
| `chapter_default.png` | An old map of the world unrolled on a wooden table by candlelight, with a quill, wax seals, a brass astrolabe and a small oil lamp: the mood of history about to be written. |

---

## 3. Moments between turns

Shown, one at a time, as the turn's events play out (marches, battles, sieges, disasters).
**Size: 3:2, at least 1200 × 800.** Use the chapter style block from set 2, with:
*"Generic for the ancient and medieval world: no particular nation, faces small or turned
away."*

| File | Prompt |
|---|---|
| `moment_march.png` | A long column of soldiers marching along a dusty road toward distant hills, banners and baggage carts, low sun. |
| `moment_battle_won.png` | Victorious soldiers raising their banners and spears on a battlefield at sunset, the enemy fleeing in the distance. |
| `moment_battle_lost.png` | A broken army retreating in the rain, wounded men helped along, abandoned shields and a torn banner in the mud. |
| `moment_siege.png` | A besieging army before high city walls, siege towers and a battering ram, archers on the walls, smoke rising. |
| `moment_city_falls.png` | Soldiers pouring through a broken city gate, the conqueror's banner raised over the gatehouse, townspeople watching. |
| `moment_sea_battle.png` | Ancient war galleys ramming one another on a choppy sea, oars shattering, men leaping between decks. |
| `moment_uprising.png` | Townspeople armed with tools and torches storming a fortified governor's house at night. |
| `moment_plague.png` | A quiet, sombre street with closed doors, a cart, a healer in a hood, smoke from burning herbs. |
| `moment_famine.png` | Dry cracked fields and withered crops under a white sky, a farmer and an ox standing still. |
| `moment_flood.png` | A great river bursting its banks over fields and a village, people on rooftops, boats rowing between houses. |
| `moment_breakthrough.png` | Craftsmen and scholars gathered around a new invention in a workshop, sparks and light, faces full of wonder. |
| `moment_festival.png` | A city square full of people celebrating: music, dancers, lanterns, banners and food stalls. |
| `moment_new_ruler.png` | A new ruler being crowned before a kneeling court in a torch-lit throne hall. |
| `moment_peace.png` | Two rulers' envoys clasping hands over a table with a sealed treaty, their guards standing at ease. |
| `moment_alliance.png` | Two rulers on horseback meeting before their armies with their banners side by side. |
| `moment_spies.png` | A cloaked figure slipping through a dark palace corridor with a scroll, lamplight behind. |

---

## 4. Buildings, as icons for the build menu

**Size: 1:1, at least 512 × 512.**

**Style block:**

> Game icon of a single building, painted in the bright, chunky, friendly 3D-cartoon style
> of mobile strategy games such as Rise of Kingdoms: seen from above at a three-quarter
> angle, the building standing on a small round patch of grass, bold clean shapes, warm
> sunlight from the upper left, soft shadow. Ancient-to-medieval look, of no particular
> nation. Centred and filling most of the square. Plain flat pale grey background
> (#D9D9D9). No text, no letters, no border, no watermark.

| File | Building |
|---|---|
| `building_granary.png` | A granary: a raised storehouse of timber and clay with sacks of grain and a cart. |
| `building_market.png` | A market: colourful awnings over stalls of fruit, cloth and pottery. |
| `building_temple.png` | A temple: a columned stone shrine with a bronze brazier burning at its steps. |
| `building_workshop.png` | A craftsmen's workshop: timber house with tools, a lathe and stacked planks outside. |
| `building_barracks.png` | Barracks: a walled yard with a long hall, a rack of spears and a training dummy. |
| `building_mine.png` | A mine: a timbered tunnel entrance in a rocky hillside, a cart of ore on rails. |
| `building_harbour.png` | A harbour: a stone quay with a moored sailing ship, crates and a crane. |
| `building_irrigation_works.png` | Irrigation works: a sluice gate and canals carrying water into green fields. |
| `building_school.png` | A school: a small courtyard house with writing boards and scrolls on shelves. |
| `building_observatory.png` | An observatory: a stone tower with a domed top and bronze star-measuring instruments on its roof. |
| `building_forge.png` | A forge: a smithy with a glowing furnace, an anvil and bellows. |
| `building_watermill.png` | A watermill: a timber mill with a big wooden wheel turning in a stream. |
| `building_windmill.png` | A windmill: a stone tower mill with four canvas sails. |
| `building_courthouse.png` | A courthouse: a dignified columned hall with steps and a set of scales over the door. |
| `building_aqueduct.png` | An aqueduct: a short run of stone arches carrying a water channel. |
| `building_printing_house.png` | A printing house: a timber workshop with a big wooden screw press and stacks of paper. |
| `building_hospital.png` | A hospital: a long hall with a herb garden and a well in the courtyard. |
| `building_academy.png` | An academy: a grand colonnaded building around a garden, with a library dome. |
| `building_bank.png` | A bank: a solid stone house with iron-bound doors and chests of coins outside. |
| `building_manufactory.png` | A manufactory: a large brick building with tall chimneys and rows of windows. |
| `building_railway_station.png` | A railway station: a brick station with a clock, a platform and a small steam engine. |

---

## 5. Title screen

| File | Prompt |
|---|---|
| `title_keyart.png` | **16:9, at least 1920 × 1080.** Epic painted key art for a historical strategy game called Meritus (but no text in the image): a vast sunlit landscape seen from a hilltop, with an ancient walled city, a Roman road, a fleet of galleys in a bay and distant mountains. In the foreground, on the hilltop, a robed figure from the ancient world holds up a small glowing modern lightbulb, casting a warm light on astonished people around him; the light is the only modern thing in the scene. Rich storybook painting style, golden-hour light, painterly brushwork. Leave the top third of the sky fairly calm (the game's name goes there). No text, no letters, no watermark. |
