# sbox-MToon

**Asset.Party link (Fallback Only): https://asset.party/edison/mtoon**

Toon Shader with Global Illumination. Ported to s&amp;box (Source 2).

![sbox_mtoon_demo](https://user-images.githubusercontent.com/5277788/202857510-282e7438-6486-467f-b082-4c604cc1840c.png)

# Source Shader
https://github.com/Santarh/MToon

# Usage

https://vrm.dev/en/univrm/shaders/shader_mtoon.html

### Highlighted sections are functional and tested.
Other sections might or might not work. Experiment yourself. UwU

Most of the default material section inputs are not used by this shader except normal map (check "Use Normal Map" if you are using a normal map).

![sbox_mtoon_usage](https://user-images.githubusercontent.com/5277788/202855945-37f5b395-89ff-4a21-ad34-14b7e00c7f0a.png)

---

### ALL texture inputs must have at least a color or valid texture file input.
The shader will not output the correct result if **any** texture has no input at all.

If some texture inputs are unused, just fill them with the default color by clicking the "Change To Color" button.

Different texture inputs might have different default colors.

![sbox_mtoon_texture_notice](https://user-images.githubusercontent.com/5277788/202855018-1a9a751f-2341-4e51-b925-403226d568fa.png)

# Limitation

- Multi-pass rendering is not yet supported (sboxgame/issues#1067). Therefore, the outline pass has not been implemented yet.
- Engine built-in shadowing and depth prepass (Shadow Caster) is different from Unity. The shadow under direct light looks weird or dirty. Might need to port the shadow caster.

# Screenshot

![sbox_mtoon_demo_1](https://user-images.githubusercontent.com/5277788/202859678-84acb33f-4477-4c04-807d-ec37c1dc3b4a.png)

![sbox_mtoon_demo_2](https://user-images.githubusercontent.com/5277788/202859717-d1afe748-e87e-40fd-9f38-795fecb2ebbd.png)

![sbox_mtoon_demo_3](https://user-images.githubusercontent.com/5277788/201977946-14832108-164c-4f9b-af71-93f289ce706e.png)

# Credits

### 3D model used in the screenshot
Eve by Hamuketsu (@ganbaru_sisters): https://sisters.booth.pm/items/2557029
