shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 sky_tint : source_color = vec4(0.882,0.835,0.937,1.0);
uniform vec4 pool_tint : source_color = vec4(0.757,0.871,0.910,1.0);
uniform vec4 mint_tint : source_color = vec4(0.824,0.945,0.882,1.0);
uniform vec4 foam_tint : source_color = vec4(0.992,0.976,0.941,1.0);
uniform int footprint_count = 0;
// xy = foundation position; z = half-width / radius; w = round column flag.
uniform vec4 footprints[16];
// Explicit footsteps, never periodic timers: x=foundation, y=start, z=gain, w=seed.
uniform vec4 ripple_events[12];
uniform float water_time = 0.0;
varying vec3 world_point;

float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float box_distance(vec2 p, float h) {
    vec2 q=abs(p)-vec2(h-0.08);
    return length(max(q,vec2(0)))+min(max(q.x,q.y),0.0)-0.08;
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_point.xz;
    float drift=noise(p*0.16+vec2(TIME*0.008,-TIME*0.006));
    float wash=smoothstep(0.05,0.95,SCREEN_UV.y);
    vec3 color=mix(sky_tint.rgb,pool_tint.rgb,wash*0.70+0.12);
    color=mix(color,mint_tint.rgb,smoothstep(0.32,0.85,drift)*0.27);
    color=mix(color,foam_tint.rgb,0.08);
    // Broad watercolor-like currents, deliberately without a dense line grid.
    float current=noise(p*0.35+vec2(TIME*0.013,0));
    color=mix(color,foam_tint.rgb,smoothstep(0.74,0.90,current)*0.075);
    float foam=0.0;
    float tint_pool=0.0;
    for(int i=0;i<16;i++) {
        if(i>=footprint_count) break;
        vec4 foundation=footprints[i];
        vec2 relative=p-foundation.xy;
        float d=foundation.w>0.5?length(relative)-foundation.z:box_distance(relative,foundation.z);
        float outside=smoothstep(-0.02,0.035,d);
        tint_pool+=exp(-max(d,0.0)*2.4)*outside*0.12;
    }
    float trough=0.0;
    for(int i=0;i<12;i++) {
        vec4 event=ripple_events[i];
        float age=water_time-event.y;
        if(event.x<0.0 || age<0.0 || age>4.8) continue;
        vec4 foundation=footprints[int(event.x)];
        vec2 relative=p-foundation.xy;
        float d=foundation.w>0.5?length(relative)-foundation.z:box_distance(relative,foundation.z);
        float outside=smoothstep(0.0,0.06,d);
        float angle=atan(relative.y,relative.x);
        // The first crest hugs the building; outgoing crests soften into rounded,
        // slightly asymmetric arcs instead of rigid, perfectly repeated outlines.
        float rounded=length(relative)-foundation.z*1.1;
        float distance=mix(d,rounded,smoothstep(0.5,3.8,age)*0.65);
        float wobble=sin(angle*3.0+event.w+age*0.8)*0.055
                    +sin(angle*5.0-event.w-age*0.45)*0.025;
        float arc=0.65+0.35*sin(angle*2.0+event.w+age*0.35);
        for(int j=0;j<3;j++) {
            float t=age-float(j)*0.32;
            if(t<0.0) continue;
            float radius=0.07+t*0.66;
            float width=0.042+t*0.018;
            float envelope=smoothstep(0.0,0.24,t)*(1.0-smoothstep(1.0,4.0,t));
            float crest=exp(-pow((distance-radius+wobble)/width,2.0));
            float low=exp(-pow((distance-radius+0.10+wobble)/(width*1.6),2.0));
            float gain=envelope*outside*arc*event.z*(1.0-float(j)*0.18);
            foam+=crest*gain*0.72;
            trough+=low*gain*0.055;
        }
    }
    color=mix(color,pool_tint.rgb,clamp(tint_pool,0.0,0.2));
    // Soft, tinted contact shade anchors the foundations without dark outlines.
    color*=1.0-clamp(tint_pool,0.0,0.22)*0.65;
    color*=1.0-clamp(trough,0.0,0.10);
    color=mix(color,foam_tint.rgb,clamp(foam,0.0,0.76));
    // Rare soft specular flecks, asynchronous rather than flashing together.
    vec2 cell=floor(p*0.65), local=fract(p*0.65)-0.5;
    float seed=hash21(cell);
    float twinkle=pow(max(sin(TIME*0.7+seed*40.0),0.0),10.0);
    float dot_glow=exp(-dot(local,local)*750.0)*step(0.80,seed)*twinkle;
    color=mix(color,foam_tint.rgb,dot_glow*0.65);
    ALBEDO=color;
}
