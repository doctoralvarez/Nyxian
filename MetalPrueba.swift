import SwiftUI
import MetalKit

/// Shader en texto: se compila en el dispositivo con makeLibrary(source:),
/// porque en iOS no existe el compilador de archivos .metal.
private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VOut {
    float4 position [[position]];
    float4 color;
};

vertex VOut vertexMain(uint vid [[vertex_id]], constant float &time [[buffer(0)]]) {
    float2 points[3] = { float2(0.0, 0.7), float2(-0.7, -0.6), float2(0.7, -0.6) };
    float4 colors[3] = { float4(1, 0, 0, 1), float4(0, 1, 0, 1), float4(0, 0, 1, 1) };
    float c = cos(time);
    float s = sin(time);
    float2 p = points[vid];
    VOut out;
    out.position = float4(p.x * c - p.y * s, p.x * s + p.y * c, 0, 1);
    out.color = colors[vid];
    return out;
}

fragment float4 fragmentMain(VOut in [[stage_in]]) {
    return in.color;
}
"""

final class TrianguloRenderer: NSObject, MTKViewDelegate {
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let start = Date()
    
    init(view: MTKView, device: MTLDevice) throws {
        guard let queue = device.makeCommandQueue() else {
            throw NSError(domain: "Prueba", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la cola de comandos"])
        }
        self.queue = queue
        
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var time = Float(Date().timeIntervalSince(start))
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}

struct MetalVista: UIViewRepresentable {
    @Binding var estado: String
    
    final class Coordinator {
        var renderer: TrianguloRenderer?
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.clearColor = MTLClearColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
        guard let device = MTLCreateSystemDefaultDevice() else {
            DispatchQueue.main.async { estado = "❌ Este dispositivo no devolvió un MTLDevice." }
            return view
        }
        view.device = device
        do {
            let renderer = try TrianguloRenderer(view: view, device: device)
            context.coordinator.renderer = renderer
            view.delegate = renderer
            let nombre = device.name
            DispatchQueue.main.async { estado = "✅ Metal OK en \(nombre): shader compilado en el dispositivo." }
        } catch {
            let mensaje = error.localizedDescription
            DispatchQueue.main.async { estado = "❌ Metal: \(mensaje)" }
        }
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

struct MetalPrueba: View {
    @State private var estado = "Iniciando Metal…"
    
    var body: some View {
        VStack(spacing: 8) {
            MetalVista(estado: $estado)
            Text(estado)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
    }
}
