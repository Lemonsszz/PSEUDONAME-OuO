// ps1_material.gdshader
// Shader estilo PS1 para Godot 4
// Aplica: vertex snapping/jitter (temblor de vertices), texturas sin filtrado (pixeladas),
// y affine texture warping simplificado.
//
// COMO USARLO:
// 1. En Godot 4, selecciona el mesh (ej. MeshInstance3D de tu casa, muebles, personaje).
// 2. En el Inspector, ve a "Material" -> "New ShaderMaterial".
// 3. Click en el material -> "Shader" -> "New Shader" o "Load" y selecciona este archivo,
//    o simplemente pega este codigo dentro de un shader nuevo.
// 4. Asigna tu textura (albedo_texture) en los parametros del shader que aparecen abajo
//    del inspector una vez asignado.
// 5. Repite para cada mesh que quieras que se vea "retro". Podes duplicar el material
//    (click derecho -> "Make Unique") si cada objeto necesita su propia textura.

shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_disabled;

// ---------------------------------------------------------
// PARAMETROS AJUSTABLES (apareceran en el Inspector de Godot)
// ---------------------------------------------------------

// Textura principal del objeto (arrastra tu imagen aca)
uniform sampler2D albedo_texture : source_color, filter_nearest;

// Color tint opcional (multiplica sobre la textura), dejalo en blanco si no queres tintar
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Resolucion de la "grilla" de snapping de vertices. Numeros mas bajos = mas temblor/distorsion.
// Valores tipicos PS1: entre 32 y 128. Prueba y ajusta a gusto.
uniform float vertex_snap_resolution : hint_range(8.0, 256.0) = 64.0;

// Intensidad del jitter (temblor) extra al moverse la camara, ademas del snapping.
uniform float jitter_strength : hint_range(0.0, 0.02) = 0.002;

// Distancia de niebla (fog) para ocultar el clipping lejano, estilo PS1.
uniform float fog_start : hint_range(0.0, 100.0) = 8.0;
uniform float fog_end : hint_range(0.0, 200.0) = 25.0;
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);

// Activa/desactiva la iluminacion "plana" tipo PS1 (sin sombreado suave)
uniform bool flat_shading_look = true;

// ---------------------------------------------------------
// VERTEX: snapping + jitter
// ---------------------------------------------------------
void vertex() {
	// Posicion en espacio de camara (view space)
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snapping: redondeamos la posicion a una grilla discreta.
	// Esto simula la baja precision de punto flotante de la PS1, que causaba
	// ese temblor caracteristico cuando la camara o los objetos se movian.
	float snap = vertex_snap_resolution;
	view_pos.xyz = floor(view_pos.xyz * snap + 0.5) / snap;

	// Jitter adicional sutil, basado en la posicion, para que no se vea perfectamente estatico
	float jitter = sin(dot(VERTEX.xyz, vec3(12.9898, 78.233, 45.164))) * 43758.5453;
	jitter = fract(jitter);
	view_pos.xy += (jitter - 0.5) * jitter_strength;

	VERTEX = (INV_PROJECTION_MATRIX * (PROJECTION_MATRIX * view_pos)).xyz;

	// Truco clave PS1: convertimos VERTEX de vuelta a espacio local usando la matriz inversa,
	// porque Godot espera VERTEX en espacio local antes de aplicar MODELVIEW_MATRIX internamente.
	VERTEX = (inverse(MODELVIEW_MATRIX) * view_pos).xyz;
}

// ---------------------------------------------------------
// FRAGMENT: texturas sin filtro + iluminacion plana + niebla
// ---------------------------------------------------------
void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;

	if (flat_shading_look) {
		// Reduce la cantidad de "pasos" de luz para simular sombreado plano/tosco
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}

// ---------------------------------------------------------
// LIGHT: opcional, fuerza sombreado en "escalones" (posterizado) como PS1
// ---------------------------------------------------------
void light() {
	float NdotL = dot(NORMAL, LIGHT);
	// Posteriza la luz en pocos escalones para look retro
	float steps = 4.0;
	float lit = floor(clamp(NdotL, 0.0, 1.0) * steps) / steps;
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR * ATTENUATION;
}
