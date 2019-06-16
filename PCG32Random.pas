(*
 * PCG 32bits Random Number Generation for Delphi/Pascal.
 * Version
 *   1.0 Initial version
 * Copyright 2019 Michel Podvin.
 *
 * MIT License
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Based On :
 * PCG, A Family of Better Random Number Generators
 * PCG is a family of simple fast space-efficient statistically good algorithms
 * for random number generation. Unlike many general-purpose RNGs, they are also
 * hard to predict.
 * Minimal C Implementation
 * Copyright 2014 Melissa O'Neill <oneill@pcg-random.org>
 *
 * For additional information about the PCG random number generation scheme,
 * including its license and other licensing options, visit
 *
 *     http://www.pcg-random.org
 *)
unit PCG32Random;

interface

(*
struct pcg_state_setseq_64 {    // Internals are *Private*.
    uint64_t state;             // RNG state.  All values are possible.
    uint64_t inc;               // Controls which RNG sequence (stream) is
                                // selected. Must *always* be odd.
};
typedef struct pcg_state_setseq_64 pcg32_random_t;
// If you *must* statically initialize it, here's one.
#define PCG32_INITIALIZER   { 0x853c49e6748fea9bULL, 0xda3e39cb94b95bdbULL }
 *)
type
  TPCG32Random = packed record
    state, inc: uint64;
  end;

  // Init state with System Time
  procedure PCG32_Randomize();overload;
  procedure PCG32_Randomize(var rng:TPCG32Random);overload;

  function PCG32_Random():uint32;overload;
  function PCG32_Random(ARange:uint32):uint32;overload;// 0 <= r < ARange

  procedure PCG32_InitRandom(var rng:TPCG32Random; initstate, initseq : uint64);overload;
  procedure PCG32_InitRandom(initstate, initseq : uint64);overload;

  function PCG32_Random(var rng:TPCG32Random):uint32;overload;
  function PCG32_Random(var rng:TPCG32Random; ARange:uint32):uint32;overload;// 0 <= r < ARange

  // Init state with GUID
  function PCG32_Randomize_GUID():boolean;overload;
  function PCG32_Randomize_GUID(var rng:TPCG32Random):boolean;overload;

  // Init state with truly random raw bytes from www.random.org
  function PCG32_Randomize_Online():boolean;overload;
  function PCG32_Randomize_Online(var rng:TPCG32Random):boolean;overload;
  procedure PCG32_Randomize_All();

implementation

uses windows, Winapi.WinInet, SysUtils;

var
  PCG32_RandSeed:TPCG32Random = ( state:$853c49e6748fea9b; inc:$da3e39cb94b95bdb );

(*
// pcg32_srandom(initstate, initseq)
// pcg32_srandom_r(rng, initstate, initseq):
//     Seed the rng.  Specified in two parts, state initializer and a
//     sequence selection constant (a.k.a. stream id)
void pcg32_srandom_r(pcg32_random_t* rng, uint64_t initstate, uint64_t initseq)
{
    rng->state = 0U;
    rng->inc = (initseq << 1u) | 1u;
    pcg32_random_r(rng);
    rng->state += initstate;
    pcg32_random_r(rng);
} *)
procedure PCG32_InitRandom(var rng:TPCG32Random; initstate, initseq : uint64);
begin
  rng.state := 0;
  rng.inc   := (initseq shl 1) or 1;
  PCG32_Random(rng);
  rng.state := rng.state + initstate;
  PCG32_Random(rng);
end;

procedure PCG32_InitRandom(initstate, initseq : uint64);
begin
  PCG32_InitRandom(PCG32_RandSeed, initstate, initseq);
end;

(*
// pcg32_random()
// pcg32_random_r(rng)
//     Generate a uniformly distributed 32-bit random number
uint32_t pcg32_random_r(pcg32_random_t* rng)
{
    uint64_t oldstate = rng->state;
    rng->state = oldstate * 6364136223846793005ULL + rng->inc;
    uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
    uint32_t rot = oldstate >> 59u;
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}*)
function PCG32_Random(var rng:TPCG32Random):uint32;
var
  oldstate:uint64;
  xorshifted, rot:uint32;
begin
  oldstate := rng.state;
  rng.state := oldstate * uint64(6364136223846793005) + rng.inc;
  xorshifted := ((oldstate shr 18) xor oldstate) shr 27;
  rot := oldstate shr 59;
  Result := (xorshifted shr rot) or (xorshifted shl ((-rot) and 31));
end;

function PCG32_Random():uint32;
begin
  Result := PCG32_Random(PCG32_RandSeed);
end;

(*
// pcg32_boundedrand(bound):
// pcg32_boundedrand_r(rng, bound):
//     Generate a uniformly distributed number, r, where 0 <= r < bound
uint32_t pcg32_boundedrand_r(pcg32_random_t* rng, uint32_t bound)
{
    // To avoid bias, we need to make the range of the RNG a multiple of
    // bound, which we do by dropping output less than a threshold.
    // A naive scheme to calculate the threshold would be to do
    //
    //     uint32_t threshold = 0x100000000ull % bound;
    //
    // but 64-bit div/mod is slower than 32-bit div/mod (especially on
    // 32-bit platforms).  In essence, we do
    //
    //     uint32_t threshold = (0x100000000ull-bound) % bound;
    //
    // because this version will calculate the same modulus, but the LHS
    // value is less than 2^32.

    uint32_t threshold = -bound % bound;

    // Uniformity guarantees that this loop will terminate.  In practice, it
    // should usually terminate quickly; on average (assuming all bounds are
    // equally likely), 82.25% of the time, we can expect it to require just
    // one iteration.  In the worst case, someone passes a bound of 2^31 + 1
    // (i.e., 2147483649), which invalidates almost 50% of the range.  In
    // practice, bounds are typically small and only a tiny amount of the range
    // is eliminated.
    for (;;) {
        uint32_t r = pcg32_random_r(rng);
        if (r >= threshold)
            return r % bound;
    }
}*)
// 0 <= r < ARange
function PCG32_Random(var rng:TPCG32Random; ARange:uint32):uint32;
var
  threshold:uint32;
begin
  threshold := -ARange mod ARange;
  while true do
  begin
    Result := PCG32_Random(rng);
    if Result >= threshold then begin Result := Result mod ARange; exit; end;
  end;
end;

function PCG32_Random(ARange:uint32):uint32;
begin
  Result := PCG32_Random(PCG32_RandSeed, ARange);
end;

(*
Windows _SYSTEMTIME = record // 16 bytes
    wYear: Word;          -
    wMonth: Word;          |  state
    wDayOfWeek: Word;      |
    wDay: Word;           -
    wHour: Word;          -
    wMinute: Word;         |  inc
    wSecond: Word;         |
    wMilliseconds: Word;  -
end;*)
procedure PCG32_Randomize(var rng:TPCG32Random);
  function rol(input:uint64; shift:cardinal):uint64;inline;
  begin
    Result:= (input shl shift) or (input shr (64-shift));
  end;
var
  Counter:int64;
  st:TSystemTime;
  rndinit: TPCG32Random absolute st;
begin
  {$IF Sizeof(st)<>Sizeof(rndinit)} {$Message Error 'Sizeof(TSystemTime) <> Sizeof(TPCG32Random)'} {$IFEND}
  GetSystemTime(st);
  if not QueryPerformanceCounter(Counter) then Counter := GetTickCount;
  PCG32_InitRandom(rng, rndinit.inc, rndinit.state xor rol(uint64(Counter), 32));
end;

procedure PCG32_Randomize();
begin
  PCG32_Randomize(PCG32_RandSeed);
end;

// based on Andreas Hausladen's code
procedure GetHexDigitsToBytes(Src: PByte; Count: Integer; Dest:PByte);
var
  Ch, Value: Byte;
begin
  Value := 0;
  while Count > 0 do
  begin
    Ch := Src^;
    case Src^ of
      Ord('0')..Ord('9'): Value := (Value shl 4) or Byte(Ch - Ord('0'));
      Ord('A')..Ord('F'): Value := (Value shl 4) or Byte(Ch - (Ord('A') - 10));
      Ord('a')..Ord('f'): Value := (Value shl 4) or Byte(Ch - (Ord('a') - 10));
      Ord(' '), $A:       begin
                            Dest^ := Value;
                            Value := 0;
                            inc(Dest);
                            Dec(Count);
                          end
    end;
    Inc(Src);
  end;
end;

function PCG32_Randomize_Online(var rng:TPCG32Random):boolean;
const
  cBytesCount = Sizeof(TPCG32Random);
var
  NetHandle: HINTERNET;
  UrlHandle: HINTERNET;
  BytesRead: DWORD;
  Url:string;
  Buffer: array[0..1023] of byte;
  tmp:TPCG32Random;
begin
  Result := false;
  try
    NetHandle := InternetOpen('Delphi 2009', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
    if Assigned(NetHandle) then
    begin
      UrlHandle := nil;
      try
        // raw bytes from www.random.org
        Url := Format('http://www.random.org/cgi-bin/randbyte?nbytes=%d&format=h', [cBytesCount]);
        UrlHandle := InternetOpenUrl(NetHandle, PChar(Url), nil, 0, INTERNET_FLAG_RELOAD, 0);
        if Assigned(UrlHandle)
           and InternetReadFile(UrlHandle, @Buffer, SizeOf(Buffer), BytesRead)
           and (BytesRead >= cBytesCount*3) then
        begin
          GetHexDigitsToBytes(@Buffer, cBytesCount, PByte(@tmp));
          PCG32_InitRandom(rng, tmp.state, tmp.inc);
          Result := true;
        end;
      finally
        if Assigned(UrlHandle) then InternetCloseHandle(UrlHandle);
        InternetCloseHandle(NetHandle);
      end;
    end;
  except
    Result := false;
  end;
end;

function PCG32_Randomize_Online():boolean;
begin
  Result := PCG32_Randomize_Online(PCG32_RandSeed);
end;

procedure PCG32_Randomize_All();
begin
  if not PCG32_Randomize_Online() then PCG32_Randomize();
end;

function PCG32_Randomize_GUID(var rng:TPCG32Random):boolean;
var
  guid:TGUID;
  tmp:TPCG32Random absolute guid;
begin
  {$IF Sizeof(guid)<>Sizeof(tmp)} {$Message Error 'Sizeof(TGUID) <> Sizeof(TPCG32Random)'} {$IFEND}
  Result := CreateGUID(guid) = 0;
  if Result then PCG32_InitRandom(rng, tmp.state, tmp.inc);
end;

function PCG32_Randomize_GUID():boolean;
begin
  Result := PCG32_Randomize_GUID(PCG32_RandSeed);
end;

end.
