"""Independent bounded BPS reader for project ROMs; no source overwrites.

Format: public-domain BPS specification, saved in planning sources.
This tool independently checks patches created with Floating IPS.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zlib


def apply_bps(source, patch, max_output_bytes=64*1024*1024):
    if len(patch) < 19 or patch[:4] != b"BPS1":
        raise ValueError("Not a complete BPS patch")
    footer=len(patch)-12
    expected_source=int.from_bytes(patch[-12:-8],"little")
    expected_target=int.from_bytes(patch[-8:-4],"little")
    expected_patch=int.from_bytes(patch[-4:],"little")
    if zlib.crc32(patch[:-4]) != expected_patch:
        raise ValueError("Patch CRC mismatch")
    if zlib.crc32(source) != expected_source:
        raise ValueError("Source CRC mismatch")
    cursor=4

    def number():
        nonlocal cursor
        data,shift=0,1
        for _ in range(10):
            if cursor >= footer:
                raise ValueError("Truncated BPS integer")
            value=patch[cursor]; cursor+=1
            data+=(value&127)*shift
            if value&128:
                return data
            shift <<= 7
            data+=shift
        raise ValueError("BPS integer exceeds bounded reader range")

    def relative():
        value=number()
        return -(value>>1) if value&1 else value>>1

    source_size,target_size,metadata_size=number(),number(),number()
    if source_size != len(source):
        raise ValueError("Exact-source size mismatch")
    if target_size > max_output_bytes:
        raise ValueError("Declared target exceeds the bounded output capacity")
    if metadata_size > footer-cursor:
        raise ValueError("Metadata extends into footer")
    cursor+=metadata_size
    result=bytearray()
    source_relative=target_relative=0
    while cursor < footer:
        action=number()
        mode,length=action&3,(action>>2)+1
        position=len(result)
        if position+length > target_size:
            raise ValueError("Action exceeds declared target extent")
        if mode==0:
            if position+length > len(source):
                raise ValueError("SourceRead outside source")
            result.extend(source[position:position+length])
        elif mode==1:
            if cursor+length > footer:
                raise ValueError("Literal exceeds patch data extent")
            result.extend(patch[cursor:cursor+length]); cursor+=length
        elif mode==2:
            source_relative+=relative()
            if not 0 <= source_relative <= len(source)-length:
                raise ValueError("SourceCopy outside source")
            result.extend(source[source_relative:source_relative+length]); source_relative+=length
        else:
            target_relative+=relative()
            for _ in range(length):
                if not 0 <= target_relative < len(result):
                    raise ValueError("TargetCopy references unavailable data")
                result.append(result[target_relative]); target_relative+=1
    if len(result)!=target_size or zlib.crc32(result)!=expected_target:
        raise ValueError("Target size or CRC mismatch")
    return bytes(result)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("patch")
    parser.add_argument("output")
    parser.add_argument("--source-sha256",required=True)
    parser.add_argument("--target-sha256",required=True)
    args=parser.parse_args()
    source_path,patch_path,output=map(lambda p:Path(p).resolve(),(args.source,args.patch,args.output))
    if output in (source_path,patch_path) or output.exists():
        raise ValueError("Output must be a new path, distinct from source and patch")
    source=source_path.read_bytes(); patch=patch_path.read_bytes()
    if hashlib.sha256(source).hexdigest()!=args.source_sha256.lower():
        raise ValueError("Exact baseline SHA-256 mismatch")
    result=apply_bps(source,patch)
    digest=hashlib.sha256(result).hexdigest()
    if digest!=args.target_sha256.lower():
        raise ValueError("Expected target SHA-256 mismatch")
    # All inputs and reconstructed bytes are checked before creating any output.
    with output.open("xb") as stream:
        stream.write(result)
    if hashlib.sha256(output.read_bytes()).hexdigest()!=digest:
        raise ValueError("Published output readback mismatch; preserve for diagnosis")
    print(json.dumps({"output":str(output),"sha256":digest,"bytes":len(result),"producer":"Independent project BPS reader; not REA Evidence"}))


if __name__=="__main__":
    main()
