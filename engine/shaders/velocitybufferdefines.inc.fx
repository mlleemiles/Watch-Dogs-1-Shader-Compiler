// Defines for materials and effects that use the velocity buffer.

#ifndef _VELOCITYBUFFERDEFINES_INC_FX_
#define _VELOCITYBUFFERDEFINES_INC_FX_


// Objects to be excluded from certain velocity effects signal it by adding a large offset to the velocity red channel.
#define VELOCITYBUFFER_MASK_OFFSET_RED      2.f

// Threshold used to detect that VELOCITYBUFFER_MASK_OFFSET_RED was applied to a velocity buffer sample.
#define VELOCITYBUFFER_MASK_THRESHOLD_RED   (VELOCITYBUFFER_MASK_OFFSET_RED * 0.5f)

// Default value of the velocity buffer's green channel, indicating that the pixel should be ignored as it doesn't represent any velocity of a dynamic object.
// See CFrameRendererBase::ms_GBufferClearColourNextGen
#define VELOCITYBUFFER_DEFAULT_GREEN        -1.f


#endif// ndef _VELOCITYBUFFERDEFINES_INC_FX_
