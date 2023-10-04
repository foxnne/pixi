<p align="center">  
  <img width="25%" src="assets/Icon1024.png">
  <h3 align=center></h3>
</p>

## Contributing

Hello and thank you so much for considering contributing to Pixi!

By suggestion, this document will hopefully serve as a good starting point for understanding Pixi's internals and where things are. However, if you ever have any questions or would like
to have a conversation about Pixi, please reach out to me on discord or add an issue. I'm "foxnne" on discord as well.

### Overview

Pixi is built using several game development libraries by others in the Zig community, as well as a C library for handling zipped files. The dependencies are as follows: 
  - **mach-core**: Handles windowing and input, and uses the new zig package manager. This library and dependencies will be downloaded to the cache on build.
  - **nfd_zig**: Native file dialogs wrapper, copied into the src/deps folder.
  - **zgui**: Wrapper for Dear Imgui, which is copied into the src/deps/zig-gamedev folder.
  - **zmath**: Math library, primarily using this for vector math and matrices. As above, this is copied into the src/deps/zig-gamedev folder.
  - **zstbi**: Wrapper for stbi provided by zig-gamedev. This handles loading and resizing images. As above, this is copied into the src/deps/zig-gamedev folder.
  - **zip**: Wrapper for the zip library, copied into the src/deps folder.

Outside of the **src** folder, we have **assets** which contain all assets that we would like to be copied over next to the executable and used by Pixi at runtime.

Inside of the **src** folder we have several subfolders. I tried to organize the project based on a few categories as follows:

- **algorithms**: This folder holds any generalized algorithms for use in pixel art operations. As of writing this, it only currently contains the brezenham algorithm used
  by the stroke/pencil tool. This algorithm handles quick mouse movements when drawing and prevents broken lines, as each frame a line is drawn from the previous frame.

- **deps**: This folder holds the previously outlined dependencies, except for those that are using the new zig package manager.
- **editor**: This folder holds individual files generally with simple *draw()* functions that mimic the layout of the editor itself. I tried to use subfolders and similar to
  set the project up in a way that was easy to understand from looking at the editor itself.
     -  i.e. editor/artboard/canvas.zig is the file responsible for the canvas within the main artboard, while editor/artboard/flipbook/canvas.zig is the canvas within the flipbook.
     -  Note that editor.zig contains a bit more than just drawing of the editor panels, and contains many of the main *editor* related functions, like loading and opening files, setting the project folder,
        saving files, and importing png files.

- **gfx**: Pixi is set up similar to a game, with the flipbook and main artboard having a camera. Each file actually has its own Camera, which allows u  
  to have individual views per file, and not a shared camera between all files. That means you can be working on two files and not have your camera move around as you switch.
    - Other things in gfx are general things related to textures, atlases, quads, etc. Some of this is unused currently and can be removed.
 
  
   

