
//node

struct Node
{
    uint Desc;
    uint Data;
    uint Valid;
    uint Leaf;
};

//Grid Offsets

static int3 grid[8] =
{
	int3(0, 0, 0),   //0
	int3(1, 0, 0),   //1
	int3(0, 1, 0),   //2
	int3(1, 1, 0),   //3
	int3(0, 0, 1),   //4
	int3(1, 0, 1),   //5
	int3(0, 1, 1),   //6
	int3(1, 1, 1)	 //7
};

uint bitsSet(uint num)
{
    uint count = 0;
    [unroll(8)]
    for (int i = 0; i < 8;i++)
    {
        if (num & 1<<i)count++;
    }
    return count;
}

uint setBitNum(uint pos, uint num)
{
    uint set = 0;
    for (uint i = 0; i<pos; i++)
    { 
        set += (num >> i) & 1;
    }

    return set;
}

 int to1Didx(int3 idx3d, int maxnum)
{
	 return idx3d.x + idx3d.y * maxnum + idx3d.z * maxnum * maxnum;
}

int3 to3Didx(int idx, int maxnum)
 {
	uint z = idx / (maxnum * maxnum);
	idx -= z * maxnum * maxnum;
	uint y = idx / maxnum;
	uint x = idx % maxnum;

    return int3(x, y, z);
}
//def

// Expands a 10-bit integer into 30 bits //taken from terro kerras nvidia
// by inserting 2 zeros after each bit.
uint expandBits(uint v)
{
    v = (v * 0x00010001u) & 0xFF0000FFu;
    v = (v * 0x00000101u) & 0x0F00F00Fu;
    v = (v * 0x00000011u) & 0xC30C30C3u;
    v = (v * 0x00000005u) & 0x49249249u;

    return v;
}

// Calculates a 30-bit Morton code for the
// given 3D point located within the unit cube [0,1].
uint morton3D(uint x, uint y, uint z)
{
    //x = min(max(x * 1024.0f, 0.0f), 1023.0f);
    //y = min(max(y * 1024.0f, 0.0f), 1023.0f);
    //z = min(max(z * 1024.0f, 0.0f), 1023.0f);
    uint xx = expandBits((uint) x);
    uint yy = expandBits((uint) y);
    uint zz = expandBits((uint) z);

    return xx * 4 + yy * 2 + zz;
}

uint compactBits(uint x) //https://fgiesen.wordpress.com/2009/12/13/decoding-morton-codes/ 
{
    x &= 0x09249249;                    // x = ---- 9--8 --7- -6-- 5--4 --3- -2-- 1--0
    x = (x ^ (x >> 2)) & 0x030c30c3;    // x = ---- --98 ---- 76-- --54 ---- 32-- --10
    x = (x ^ (x >> 4)) & 0x0300f00f;    // x = ---- --98 ---- ---- 7654 ---- ---- 3210
    x = (x ^ (x >> 8)) & 0xff0000ff;    // x = ---- --98 ---- ---- ---- ---- 7654 3210
    x = (x ^ (x >> 16)) & 0x000003ff;   // x = ---- ---- ---- ---- ---- --98 7654 3210
    return x;
}


uint3 coord3D(uint morton)
 {
    uint x = compactBits(morton>>2);
    uint y = compactBits(morton>>1);
    uint z = compactBits(morton);

    return uint3(x, y, z);
}


#define BLOCK_SIZE 32
#define OCTREE_BUILDER_GP_SIZE 8
#define TEXTURE_SIZE 256

