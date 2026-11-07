import SwiftUI
import SpriteKit

/// Pelotas que rebotan con física. Si se mueven, SpriteKit funciona.
/// Usa SKView dentro de UIViewRepresentable en lugar de SpriteView: SpriteView viene de un
/// módulo puente SpriteKit+SwiftUI que Nyxian no carga, y SKView existe en cualquier SDK.
final class RebotesEscena: SKScene {
    private var creadas = false
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        guard !creadas else { return }
        creadas = true
        for i in 0..<12 {
            let ball = SKShapeNode(circleOfRadius: 18)
            ball.fillColor = UIColor(hue: CGFloat(i) / 12, saturation: 0.8, brightness: 1, alpha: 1)
            ball.strokeColor = .clear
            ball.position = CGPoint(x: frame.midX + CGFloat(i * 10 - 60), y: frame.midY + CGFloat(i * 20))
            ball.physicsBody = SKPhysicsBody(circleOfRadius: 18)
            ball.physicsBody?.restitution = 0.9
            addChild(ball)
        }
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
    }
}

struct VistaSpriteKit: UIViewRepresentable {
    let escena: SKScene
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.presentScene(escena)
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {}
}

struct SpriteKitPrueba: View {
    private let escena: RebotesEscena = {
        let escena = RebotesEscena(size: CGSize(width: 390, height: 600))
        escena.scaleMode = .resizeFill
        return escena
    }()
    
    var body: some View {
        VStack(spacing: 8) {
            VistaSpriteKit(escena: escena)
            Text("SpriteKit: deberías ver pelotas de colores rebotando.")
                .font(.footnote)
                .padding(.bottom, 8)
        }
    }
}
