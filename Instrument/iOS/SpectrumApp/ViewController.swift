import UIKit
import AudioToolbox
import SpectrumFramework

class ViewController: UIViewController {
    class Text: UILabel {
        convenience init(_ content: String) {
            self.init(frame: CGRect.zero)
            text = content
            textColor = .white
            translatesAutoresizingMaskIntoConstraints = false
            textAlignment = .center
            numberOfLines = 0
            lineBreakMode = .byWordWrapping
        }
    }
    
    class Button: UIButton {
        convenience init(_ text: String, _ url: String) {
            self.init(frame: CGRect.zero)
            setTitle(text, for: .normal)
            backgroundColor = UIColor.black
            setTitleColor(.white, for: .normal)
            layer.borderColor = UIColor.white.cgColor
            contentEdgeInsets = UIEdgeInsets(top: 5.0, left: 5.0, bottom: 5.0, right: 5.0)

            layer.borderWidth = 1.0
            layer.cornerRadius = 10
        }
    }
    
    // MARK: View Life Cycle
	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = UIColor.init(hex: "#111111ff")!
        navigationController?.view.backgroundColor = UIColor.init(hex: "#111111ff")!
        
        title = "Spectrum"
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        
        let scroll = UIScrollView()
        
        view.addSubview(scroll)
        scroll.addSubview(stack)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(scroll.constraints(safelyFilling: view))
        
        let constraints = [
          stack.topAnchor.constraint(equalToSystemSpacingBelow: scroll.topAnchor, multiplier: 1.0),
          stack.leadingAnchor.constraint(equalToSystemSpacingAfter: scroll.leadingAnchor, multiplier: 1.0),
          scroll.trailingAnchor.constraint(equalToSystemSpacingAfter: stack.trailingAnchor, multiplier: 1.0),
          stack.bottomAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: scroll.bottomAnchor, multiplier: 1.0),
          view.trailingAnchor.constraint(equalToSystemSpacingAfter: stack.trailingAnchor, multiplier: 1.0)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        ui().forEach { stack.addArrangedSubview($0) }
    }
    
    func ui() -> [UIView] {
        return [
          Text("Spectrum"),
          Text("Spectrum Audio Units are now installed."),
          Text("To use Spectrum you need an Audio Unit Host or DAW like AUM or Garageband."),
          Button("Spectrum Manual", ""),
          Text("Spectrum is based on Eurorack modules by Mutable Instruments.  If you like it, support Mutable Instruments by buying their hardware."),
          Button("Mutable Instruments Home", ""),
          Text("Spectrum Audio Units have been built by Tom Burns.  If you want to support my work consider buying one of my other apps.  Thanks!"),
          Button("App Store", ""),
          Text("Follow Burns Audio to keep up to date with my latest software and music releases"),
          Button("Instagram", ""),
          Button("Youtube", ""),
          Button("Email", "")
        ]
    }
}
