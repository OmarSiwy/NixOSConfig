# Targets, Build Commands, and Host Runtimes

How to compile Zig kernels for each GPU backend and what runs the result. Target triples, `-mcpu` features, and flags are version-sensitive; verify with `zig targets` and `zig version`.

## The four backends at a glance

| Backend | Target triple | Backend used | Output | Consumed by |
|---|---|---|---|---|
| SPIR-V / Vulkan | `spirv64-vulkan-none` | self-hosted (`-fno-llvm`) | `.spv` | Vulkan `vkCreateShaderModule`, WebGPU |
| SPIR-V / OpenCL | `spirv64-opencl-none` | self-hosted (`-fno-llvm`) | `.spv` | OpenCL `clCreateProgramWithIL` |
| NVPTX / CUDA | `nvptx64-cuda-none` | LLVM | PTX asm | CUDA Driver API `cuModuleLoadData` |
| AMDGCN / AMD | `amdgcn-amdhsa-none` | LLVM | code object | HIP / HSA runtime |

There is also a 32-bit `spirv32` for environments that require it.

## Build commands

```bash
# SPIR-V (Vulkan): self-hosted backend, emit SPIR-V binary
zig build-obj -target spirv64-vulkan-none -mcpu vulkan_v1_2+int64 -ofmt=spirv -fno-llvm kernel.zig

# SPIR-V (OpenCL)
zig build-obj -target spirv64-opencl-none -mcpu opencl_v2+int64 -ofmt=spirv -fno-llvm kernel.zig

# NVPTX (CUDA): emit PTX assembly, no binary, no UBSan runtime
zig build-lib -dynamic -target nvptx64-cuda-none -mcpu <gpu-model> -femit-asm -fno-emit-bin -fno-ubsan-rt kernel.zig

# AMDGCN (AMD): drop compiler-rt for the freestanding device target
zig build-lib -dynamic -target amdgcn-amdhsa-none -mcpu <gpu-model> -fno-compiler-rt kernel.zig
```

Why the flags differ:
- **`-fno-llvm`** on SPIR-V selects Zig's self-hosted SPIR-V backend (SPIR-V is not produced through LLVM).
- **`-mcpu`** carries the environment version and feature set. For SPIR-V, `vulkan_v1_2` / `opencl_v2` plus features like `+int64`. For PTX/AMDGCN, the concrete GPU model (e.g. a `sm_xx` class for NVIDIA or a `gfxXXXX` for AMD) — pick the one matching your hardware, exactly as you would pass `-arch`/`--offload-arch` to nvcc/hipcc in the sibling skill.
- **`-femit-asm -fno-emit-bin`** on PTX produces the PTX text the CUDA driver loads, rather than a host binary.
- **`-fno-ubsan-rt` / `-fno-compiler-rt`** drop host runtime support that has no meaning in the freestanding device environment.

## Picking `-mcpu` for PTX and AMDGCN

The GPU model determines available instructions and, indirectly, occupancy limits. Match the silicon: an NVIDIA compute-capability target for PTX, a `gfx` ISA for AMDGCN (the same `gfx90a` / `gfx942` families discussed in `gpu-kernel-engineering`'s portability reference). Building for the wrong model can fail to load or fall back to slow paths.

## Validate the artifact

For SPIR-V, run `spirv-val` on the emitted `.spv`. Zig's goal is that `spirv-val` never fails on backend output, so a validation failure is a bug worth reporting — and a signal not to ship that module. For PTX/AMDGCN, the real test is loading and running on hardware against a CPU reference oracle.

## Host runtime, briefly

The kernel artifact is inert until a host program loads and launches it. You can write that host in Zig with `@cImport` over the Vulkan / OpenCL / CUDA-driver / HIP headers, or use a wrapper library. See `references/c-interop.md`. The launch geometry (grid × workgroup) you pass on the host must agree with the `local_size` you set via `gpu.executionMode` on the device side.
