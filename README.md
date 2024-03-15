URP Volume Intersection - "Omnidirectional Stencil"

visual examples can be found here: https://www.artstation.com/artwork/elwgBJ

Rendering a Volume only where its intersecting with other geometry using the stencil buffer.
Project contains a few different examples - basic triplanar projection, world xz projection, world normal visualization. 


========================== how it works =======================

the effect is actually quite simple:
- the first pass writes only back faces BEHIND other geometry into the stencil buffer
- the second pass renders only front faces where the first pass has already wirrten into the stencil buffer
this effectively means every geo INSIDE the volume will be colored.

because URP doesnt support multiple passes, i have split them up into spearate materials on the same object and adjusted their rendering order manually.


========== Built In Render Pipeline =================

if you want you can combine both renderers into a single one with both passes, thats it :)
