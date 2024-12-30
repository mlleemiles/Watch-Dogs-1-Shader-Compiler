#ifndef BITS_INC_FX
#define BITS_INC_FX

int EncodeFlags(bool v1)
{
	return (v1 ? 1 : 0);
}

int EncodeFlags(bool v1, bool v2)
{
	return EncodeFlags(v1) + (v2 ? 2 : 0);
}

int EncodeFlags(bool v1, bool v2, bool v3)
{
	return EncodeFlags(v1, v2) + (v3 ? 4 : 0);
}

int EncodeFlags(bool v1, bool v2, bool v3, bool v4)
{
	return EncodeFlags(v1, v2, v3) + (v4 ? 8 : 0);
}

int EncodeFlags(bool v1, bool v2, bool v3, bool v4, bool v5)
{
	return EncodeFlags(v1, v2, v3, v4) + (v5 ? 16 : 0);
}

int EncodeFlags(bool v1, bool v2, bool v3, bool v4, bool v5, bool v6)
{
	return EncodeFlags(v1, v2, v3, v4, v5) + (v6 ? 32 : 0);
}

void DecodeFlags(float encodedBits, out bool flag1)
{
	flag1 = fmod(encodedBits, 2) == 1;
}

void DecodeFlags(float encodedBits, out bool flag1, out bool flag2)
{
	DecodeFlags(encodedBits, flag1);
	flag2 = fmod(encodedBits, 4) >= 2;
}

void DecodeFlags(float encodedBits, out bool flag1, out bool flag2, out bool flag3)
{
	DecodeFlags(encodedBits, flag1, flag2);
	flag3 = fmod(encodedBits, 8) >= 4;
}

void DecodeFlags(float encodedBits, out bool flag1, out bool flag2, out bool flag3, out bool flag4)
{
	DecodeFlags(encodedBits, flag1, flag2, flag3);
	flag4 = fmod(encodedBits, 16) >= 8;
}

void DecodeFlags(float encodedBits, out bool flag1, out bool flag2, out bool flag3, out bool flag4, out bool flag5)
{
	DecodeFlags(encodedBits, flag1, flag2, flag3, flag4);
	flag5 = fmod(encodedBits, 32) >= 16;
}

void DecodeFlags(float encodedBits, out bool flag1, out bool flag2, out bool flag3, out bool flag4, out bool flag5, out bool flag6)
{
	DecodeFlags(encodedBits, flag1, flag2, flag3, flag4, flag5);
	flag6 = fmod(encodedBits, 64) >= 32;
}

float CompressFlags(int flags)
{
	return (float)flags / 255.0f;
}

int UncompressFlags(float rawEncodedBits)
{
	return (int)floor(rawEncodedBits * 255.0f + 0.5f);
}

#endif // BITS_INC_FX
