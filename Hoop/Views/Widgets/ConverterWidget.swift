import SwiftUI

struct ConverterWidgetView: View {
    @State private var category: ConversionCategory = .length
    @State private var inputValue: String = ""
    @State private var sourceUnit: Int = 0
    @State private var targetUnit: Int = 1

    enum ConversionCategory: String, CaseIterable {
        case length = "Length"
        case weight = "Weight"
        case temperature = "Temp"

        var units: [(String, String)] { // (label, abbreviation)
            switch self {
            case .length:
                return [("Meters", "m"), ("Feet", "ft"), ("Inches", "in"),
                        ("Centimeters", "cm"), ("Kilometers", "km"), ("Miles", "mi")]
            case .weight:
                return [("Kilograms", "kg"), ("Pounds", "lb"), ("Ounces", "oz"),
                        ("Grams", "g")]
            case .temperature:
                return [("Celsius", "°C"), ("Fahrenheit", "°F"), ("Kelvin", "K")]
            }
        }
    }

    private var result: String {
        guard let value = Double(inputValue) else { return "—" }
        let converted = convert(value, from: sourceUnit, to: targetUnit, category: category)
        if converted == converted.rounded() && abs(converted) < 1_000_000 {
            return String(format: "%.0f", converted)
        }
        return String(format: "%.2f", converted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Converter")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            // Category selector
            HStack(spacing: 4) {
                ForEach(ConversionCategory.allCases, id: \.rawValue) { cat in
                    Button {
                        category = cat
                        sourceUnit = 0
                        targetUnit = 1
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(category == cat ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(category == cat ? .white.opacity(0.15) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Input row
            HStack(spacing: 6) {
                TextField("0", text: $inputValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))

                unitPicker(selection: $sourceUnit)

                Button {
                    let tmp = sourceUnit
                    sourceUnit = targetUnit
                    targetUnit = tmp
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)

                unitPicker(selection: $targetUnit)
            }

            // Result
            HStack {
                Text(result)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(category.units[targetUnit].1)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func unitPicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(category.units.enumerated()), id: \.offset) { index, unit in
                Text(unit.1).tag(index)
            }
        }
        .labelsHidden()
        .frame(width: 50)
    }

    // MARK: - Conversion Logic

    private func convert(_ value: Double, from source: Int, to target: Int, category: ConversionCategory) -> Double {
        switch category {
        case .length:
            let toMeters: [Double] = [1, 0.3048, 0.0254, 0.01, 1000, 1609.34]
            let inMeters = value * toMeters[source]
            return inMeters / toMeters[target]
        case .weight:
            let toKg: [Double] = [1, 0.453592, 0.0283495, 0.001]
            let inKg = value * toKg[source]
            return inKg / toKg[target]
        case .temperature:
            // Convert to Celsius first, then to target
            let celsius: Double
            switch source {
            case 0: celsius = value
            case 1: celsius = (value - 32) * 5 / 9
            case 2: celsius = value - 273.15
            default: celsius = value
            }
            switch target {
            case 0: return celsius
            case 1: return celsius * 9 / 5 + 32
            case 2: return celsius + 273.15
            default: return celsius
            }
        }
    }
}

// MARK: - Widget Conformance

final class ConverterNotchWidget: NotchWidget {
    let id = "converter"
    let name = "Converter"
    let icon = "arrow.left.arrow.right"
    let size: WidgetSize = .large

    @MainActor
    func makeBody() -> AnyView {
        AnyView(ConverterWidgetView())
    }
}
