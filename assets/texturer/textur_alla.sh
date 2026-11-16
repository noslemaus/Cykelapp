#!/bin/zsh
# Prepare, paint and build every textured model in one go (TextureCraft must be running with
# --control 7878). Usage: assets/texturer/textur_alla.sh [model ...]  (default: the list below, all
# of them; the tank is painted by stridsvagn/bygg_textur.py and only built by textur_bygg.py)
set -e
cd "$(dirname "$0")/../.."
MODELS=(gulstuga vitstuga blastuga storgard gronstuga kyrka cafe lada uthus klockstapel
  eka eka_gron roddbat snipa fiskebat segelbat segelbat_bla segelbat_forto kajak skargardsbat
  brygga gastbrygga badbrygga fyr bak natstallning vedtrave gammal_bil hamnprylar livbojsstall brevlada
  cafebord utemobler midsommarstang cyklist zombie alien pysare ufo hangar barack radar vakttorn lastbil bom
  sandsackar drivmedel helipad bergrum lador kamonat rodstuga sjobod
  pyramid_stor pyramid_mellan pyramid_liten pyramid_drottning sfinx obelisk pylon kolonnad sfinx_liten staty_farao
  hus_kairo_1 hus_kairo_2 hus_kairo_3 hus_kairo_4 moske minaret basar_kryddor basar_mattor basar_lyktor basar_krukor
  markis kamel kamel_ligg felucca talt_beduin lejonstaty talt_vit stralkastare sarkofag flakbil mumie farao skarabe
  abusimbel terrasstempel staty_staende citadell ballong_1 ballong_2 duvtorn vattenhjul lerhus asnekarra
  automat dohyo dojo drake gatlykta geisha gyoji kitsune machiya_1 machiya_2 machiya_3 neonhus_1 neonhus_2 neonhus_3
  ninja oni pagod3 pagod5 samurai shinkansen skyskrapa_1 skyskrapa_2 skyskrapa_3 slott stenlykta sumo taikobashi
  tempelhall tokyotorn torii torii_stor viadukt yatai vattenfall elstolpe cyklar keibil postlada jizo lykta_par krukor
  kraka yakatabune koi kontorist skolelev tanuki komainu temizuya hokora takegaki kakashi hager koinobori munk turist
  busskur
  ryokan gassho chaya pariserhjul fiskebat_jp fyr_jp teleportport@japan teleportport@egypten
  ko_rod ko_svart ko_bete far_1 far_2 mas ejdrar kummel prick_rod prick_gron boj flaggstang vimpelstang tvattlina
  kyrkmur gravstenar skylt_vag_h skylt_vag_v skylt_cykel skylt_skydd
  faros gravport memnon philae hus_nubisk_1 hus_nubisk_2 hus_nubisk_3 obelisk_oavslutad pelare_pompejus teater
  man_galabeya kvinna_kruka handlare_karra budcykel taxi_kairo tuktuk flodpram kryssningsbat fiskebat_nil barn_1 barn_2
  fotboll turist_kamel arkeolog_1 arkeolog_2 guide_paraply turist_1 turist_2 asna get_1 get_2 ibis katt_1 katt_2
  vattenbuffel tehus vattenpipscafe tvattlina_eg parabol fruktstand mattforsaljare
  fiskare_brygga badare solbadare jolle fikagast_1 fikagast_2 dansare_1 dansare_2 sal svan hast radjur lagereld talt
  cykel_parkerad motorbat promenerare hund traktor hangmatta barn_glass
  miko skolbarn mamachari rikscha mikoshi taxi@japan keilastbil moped svanbat fiskare teplockare risbonde pilgrim
  forsaljare taiko yukatapar hjort trana katt apa shiba pachinko telefonkiosk tempelklocka maneki_neko wagasa kingyo
  nobori ema trafikljus)
# name@world picks one world's model where two share a name (both teleport gates are "teleportport").
(( $# )) && MODELS=("$@")
blender --background --python assets/blender/textur_prep.py -- $MODELS 2>&1 | grep -E "förberedd|Error"
python3 assets/texturer/textur_mala.py $MODELS
blender --background --python assets/blender/textur_bygg.py -- $MODELS 2>&1 | grep -E "byggde|saknar|Error"
# Godot extracts the textures on import; make them VRAM-compressed (fast loading) and import again.
(cd game && godot --headless --import >/dev/null 2>&1)
python3 assets/texturer/vram.py
(cd game && godot --headless --import >/dev/null 2>&1)
