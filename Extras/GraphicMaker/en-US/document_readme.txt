――――――――――――――――――――――――――――――――――
        Graphic Maker Readme
――――――――――――――――――――――――――――――――――

[ What Is This Tool? ]

This tool generates a single new image by combining image parts.
By default, it can combine 8-direction sprites for WOLF RPG Editor.
Files you create using the data included with this tool
can be used for any purpose, not just games.
(Examples: website icons, video assets, Flash assets, etc.)


[ If This Tool Won't Start Due to Gdiplus.dll ]

This error occurs because Gdiplus.dll is not installed on your computer.
Copy the "Gdiplus.dll" file from the WOLF RPG Editor folder into the Graphic Maker folder,
or place Gdiplus.dll into your Windows System32 folder.
(Currently, WOLF RPG Editor does not include the Gdiplus.dll file.)


[ Data Settings ]

You can set the size of the generated images and the order in which
parts are layered by editing the Setting.txt file in each data folder.
For an example setting, refer to the Setting.txt file in "Graphics\Character Sprite."


[ How to Create Parts ]

Any image that matches the size specified in Setting.txt
and is a PNG with a transparent color or an alpha channel can be used.
Semi-transparent images can also be layered.

――――――――――――――――――――――――――――――――――
[ Terms of Use ]
- Generated images may be used in both commercial and non-commercial works.
- Modification of generated images and part images is allowed.
  (Redistribution of the modified images is also allowed.)
- Redistribution of the part images is allowed.
  (However, commercial sale of the part images themselves is prohibited.)
- No name attribution is required in end credits or similar places.
- Use in tools other than WOLF RPG Editor is also allowed.
――――――――――――――――――――――――――――――――――
[ Extras: Character Sprite Base ]
The "CharacterSpriteBase" images (created by pochi) included in the "Extras"
folder are base images for the Character Sprite.
When creating new parts, drawing them on top of these images makes it easier
to align positions and match sizes.
――――――――――――――――――――――――――――――――――
[ Character Sprite Parts Contributors ] (From WOLF RPG Editor Asset Submission Thread)
 pochi - thank you for helping with 8‑direction conversions, size adjustments, refinements, and more
 すう (Suu) - thank you for creating the base 4‑direction sprites
 まーべ(Maabe), 枯れ草(Karekusa), mel, 藤田るいふ(Fujita Ruifu), MAT, さと(Sato),
 ヨシユキ(Yoshiyuki), ふぃく(Fiku), ウロっち(Urotchi), 和壺(Watsubo), CEO, はつや(Hatsuya),
 尾羽(Oha), にせな(Nisena), くくり姫(Kukurihime), ユノ(Yuno): basic parts
 たつき (Tatsuki): skin parts
 りくがめ (Rikugame): many parts
――――――――――――――――――――――――――――――――――
[ Portrait Parts Contributors ] (From Portrait Graphic Maker Project Page)
 いさあきえーと (Isaaki eight) - thank you for creating the base images for all types
 korcs, うみの(Umino), haji, kk, たては(Tateha), タケゾウ(Takezou), van,
 ぜふぃ(Zefi), あきら(Akira), アマニア(Amania), 雪雹(Yukihyo), 蛍(Hotaru),
 ミンミン(Minmin), 計架(Keika), まーりん(Maarin), もりもる(Morimoru), 沙木恵(Saboku Megumi)
――――――――――――――――――――――――――――――――――
[ Update History ] (Parts submitted in the Asset Thread are added when appropriate)
06/18/2010 - Increased the number of parts from 8 to 12
           - Added manual display order settings for $parts
           - Added color-linking feature
           - Added "Size x0.5" save option
05/14/2010 - Fixed incorrect layering behavior for images with layer order 0
05/11/2010 - Added full support for alpha-channel images (by rikka)
           - Added hue and saturation adjustment feature (by rikka)
09/14/2009 - Added 2x/3x display feature
10/29/2008 - Enlarged all images and replaced them with refined parts
           - Added Randomize feature
09/06/2008 - Initial release
――――――――――――――――――――――――――――――――――

Developers: SmokingWOLF [http://www.silversecond.net/] (Japanese)
            六花 (rikka)
