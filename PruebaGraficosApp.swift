// Prueba de frameworks gráficos en Nyxian: SceneKit, Metal (shader compilado en tiempo de ejecución) y SpriteKit.
import SwiftUI

@main
struct PruebaGraficosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            SceneKitPrueba()
                .tabItem { Label("SceneKit", systemImage: "cube") }
            MetalPrueba()
                .tabItem { Label("Metal", systemImage: "triangle") }
            SpriteKitPrueba()
                .tabItem { Label("SpriteKit", systemImage: "circle.hexagongrid") }
        }
    }
}
