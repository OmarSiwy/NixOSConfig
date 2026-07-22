# C-Interop: Driving CUDA/HIP from Zig

When native Zig kernels are not mature enough for a given workload, or you need proven libraries (cuBLAS, cuDNN, rocBLAS) today, keep the kernels in CUDA/HIP and use Zig for the host side. This is the pragmatic path while Zig's native GPU support matures.

## Three interop strategies

1. **Host-only interop** — write kernels in `.cu`/`.hip`, compile them with `nvcc`/`hipcc` into a library, and call that library from Zig host code via `@cImport`. Zig manages the application; the vendor toolchain manages the kernels.
2. **Driver-API loading** — compile kernels to PTX (including Zig-native PTX from `targets-and-build.md`) and load them at runtime through the CUDA Driver API (`cuModuleLoadData`, `cuLaunchKernel`) imported with `@cImport`. No nvcc needed at build time if the PTX already exists.
3. **Wrapper library** — use `cudaz`, a Zig CUDA library that exposes grid/block/thread launch configuration in Zig terms. Fetch it with `zig fetch --save` and add it as a dependency in `build.zig`.

## Importing the runtime headers

```zig
const cuda = @cImport({
    @cInclude("cuda_runtime.h"); // or "cuda.h" for the driver API; "hip/hip_runtime.h" for HIP
});

// Then call the C API directly:
// _ = cuda.cudaMalloc(&dev_ptr, n * @sizeOf(f32));
// _ = cuda.cudaMemcpy(dev_ptr, host_ptr, bytes, cuda.cudaMemcpyHostToDevice);
```

For C++ CUDA code, expose a C ABI from the C++ side with `extern "C"` wrapper functions, since Zig consumes C, not C++ name-mangled symbols.

## build.zig integration

The host build must find headers and link the runtime (and any nvcc-compiled object):

```zig
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });
    exe.linkLibC();
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/cuda/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/usr/local/cuda/lib64" });
    exe.linkSystemLibrary("cudart"); // or "cuda" for the driver API; ROCm libs for HIP
    // Optionally add an object produced by nvcc from your .cu kernels:
    // exe.addObjectFile(b.path("zig-cache/kernels.o"));
    b.installArtifact(exe);
}
```

Paths and library names vary by install and platform; adjust to your CUDA/ROCm location. To compile `.cu` files as part of the build, invoke `nvcc` through `b.addSystemCommand(...)` and feed the resulting object to `addObjectFile`.

## Using the cudaz library

```bash
zig fetch --save https://github.com/akhildevelops/cudaz/archive/<version>.tar.gz
```

Then declare it as a dependency in `build.zig` and add the module so it links into your binary. It wraps device memory, transfers, and kernel launches with grid/block/thread configuration in Zig style. Check its test folder for runnable examples.

## When to choose interop over native

- You need a mature, optimized library (BLAS, FFT, DNN primitives) — use the vendor library via interop.
- You need it working on hardware *now* with predictable performance — interop.
- You want one language, no vendor toolchain, and can tolerate experimental edges — native Zig (the rest of this skill).

Whichever you pick, the performance characteristics of the kernels themselves are governed by the hardware model in `gpu-kernel-engineering`; interop changes who *writes* the kernel, not what makes it fast.
