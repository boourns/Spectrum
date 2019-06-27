import UIKit
import SpectrumFramework

class ViewController: UIViewController {
    class Text: UILabel {
        convenience init(_ content: String, font: UIFont = UIFont.preferredFont(forTextStyle: .body)) {
            self.init(frame: CGRect.zero)
            text = content
            textColor = .white
            translatesAutoresizingMaskIntoConstraints = false
            textAlignment = .center
            numberOfLines = 0
            lineBreakMode = .byWordWrapping
            self.font = font
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
            clipsToBounds = true
            
            addControlEvent(.touchUpInside) {
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    class ImageButton: UIButton {
        convenience init(_ image: String, _ url: String) {
            self.init(frame: CGRect.zero)
            setImage(UIImage(named: image), for: .normal)

            layer.cornerRadius = 10
            clipsToBounds = true
            widthAnchor.constraint(equalToConstant: 80).isActive = true
            heightAnchor.constraint(equalToConstant: 80).isActive = true
            
            addControlEvent(.touchUpInside) {
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            }

        }
    }
    
    class HStack: UIStackView {
        convenience init(_ children: [UIView]) {
            self.init()
            
            axis = .horizontal
            alignment = .fill
            distribution = .fillEqually
            spacing = 20
            translatesAutoresizingMaskIntoConstraints = false
            
            children.forEach { addArrangedSubview($0) }
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
            Text("Spectrum", font: UIFont.preferredFont(forTextStyle: .title1)),
          Text("Spectrum Audio Units are now installed."),
          Text("To use Spectrum you need an Audio Unit Host or DAW like AUM or Garageband."),
          Text("Spectrum is based on Eurorack modules by Mutable Instruments.  If you like it, support Mutable Instruments by buying their hardware."),
          Button("Mutable Instruments Home", "https://mutable-instruments.net"),
          Text("Spectrum Audio Units have been built by Tom Burns.  If you want to support my work consider buying one of my other apps.  Thanks!"),
          Button("App Store", "https://apps.apple.com/ca/developer/thomas-burns/id522224284"),
          Text("Follow Burns Audio to keep up to date with my latest software and music releases"),
          HStack([ImageButton("Instagram", "https://www.instagram.com/gravitronic/"),
          ImageButton("Youtube", "https://www.youtube.com/channel/UCbZ29esNP4GrR2zkUdScFNw"),
          ImageButton("Email", "https://burns.ca/newsletter.html")])
        ]
    }
}
