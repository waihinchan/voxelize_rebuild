float remap (float value, float from1, float to1, float from2, float to2) {
	return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
}
float4 lerpvertex(float3 newpos, float3 oldpos, float pragma){
	return float4(lerp(oldpos,newpos,pragma),1); 
}