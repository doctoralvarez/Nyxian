import SwiftUI
import SceneKit

/// Un cubo girando. Si se ve, SceneKit compila, enlaza y dibuja.
struct SceneKitPrueba: View {
    private let scene: SCNScene = {
        let scene = SCNScene()
        let box = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.08))
        box.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal
        box.runAction(.repeatForever(.rotateBy(x: 1, y: 2, z: 0, duration: 3)))
        scene.rootNode.addChildNode(box)
        
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(camera)
        return scene
    }()
    
    var body: some View {
        VStack(spacing: 8) {
            SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
            Text("SceneKit: deberías ver un cubo girando (arrástralo para rotarlo).")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
    }
}
