import SwiftUI
import PhotosUI      // Para el selector de fotos (PhotosPicker)
import CoreImage    // El motor de procesamiento de imágenes
import CoreImage.CIFilterBuiltins // Acceso simplificado a los filtros (Sepia, Noir, etc.)

// MARK: - 1. MODELO DE DATOS
// Estructura que representa una foto ya editada y guardada en la comparativa
struct FilteredVersion: Identifiable, Equatable {
    let id = UUID()           // ID único para que SwiftUI pueda listarlos
    let image: UIImage        // La imagen final con los filtros aplicados
    let filterName: String    // Nombre descriptivo (ej: "Sepia (+20%)")
    
    // Función para que SwiftUI sepa si dos versiones son la misma (basado en ID)
    static func == (lhs: FilteredVersion, rhs: FilteredVersion) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 2. VIEWMODEL (Lógica de Negocio)
// Esta clase controla los datos y el procesamiento de las fotos
class FilterViewModel: ObservableObject {
    // Referencias de imagen: Original (fuente) y Preview (lo que se ve ahora)
    @Published var originalImage: UIImage?
    @Published var currentPreview: UIImage?
    @Published var savedVersions: [FilteredVersion] = [] // Lista del carrusel inferior
    
    // Estados de edición actuales
    @Published var activeFilterCode: String? = nil    // Código técnico del filtro
    @Published var activeFilterName: String = "Original"
    @Published var brightnessValue: Float = 0.0       // Valor del slider (-1.0 a 1.0)
    
    // Observador para cuando el usuario elige una foto en la galería
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet { if let imageSelection { loadOriginal(from: imageSelection) } }
    }
    
    // Contexto de Core Image: Se crea una vez para mejorar el rendimiento
    private let context = CIContext()

    // Función asíncrona para cargar la imagen seleccionada de la galería
    private func loadOriginal(from item: PhotosPickerItem) {
        Task {
            // Intentamos obtener los datos de la foto
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Actualizamos la UI en el hilo principal
                await MainActor.run {
                    self.originalImage = uiImage
                    self.currentPreview = uiImage
                    self.savedVersions = [] // Limpiamos ediciones previas
                    self.resetEdits()
                }
            }
        }
    }

    // Reinicia los valores de edición a cero
    func resetEdits() {
        activeFilterCode = nil
        activeFilterName = "Original"
        brightnessValue = 0.0
        currentPreview = originalImage
    }

    // --- EL MOTOR DE FILTROS ---
    // Aplica el filtro de color y el brillo empezando siempre desde la original
    func applyAllFilters() {
        guard let input = originalImage,
              var ciImage = CIImage(image: input) else { return }
        
        // 1. Aplicamos el filtro de color (si hay uno seleccionado)
        if let filterCode = activeFilterCode {
            let colorFilter = CIFilter(name: filterCode)
            colorFilter?.setValue(ciImage, forKey: kCIInputImageKey)
            if let output = colorFilter?.outputImage { ciImage = output }
        }
        
        // 2. Aplicamos el ajuste de brillo (Exposure Adjust)
        let brightnessFilter = CIFilter(name: "CIExposureAdjust")
        brightnessFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        brightnessFilter?.setValue(brightnessValue, forKey: kCIInputEVKey)
        
        // 3. Renderizamos la imagen final usando la GPU
        if let output = brightnessFilter?.outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            // Creamos la UIImage final manteniendo la orientación original de la cámara
            let result = UIImage(cgImage: cgImage, scale: input.scale, orientation: input.imageOrientation)
            // Actualizamos la vista de forma asíncrona
            DispatchQueue.main.async { self.currentPreview = result }
        }
    }

    // Cambia el filtro actual y procesa la imagen
    func selectFilter(code: String, name: String) {
        self.activeFilterCode = code
        self.activeFilterName = name
        applyAllFilters()
    }

    // Guarda la edición actual en la lista inferior (Carrusel)
    func saveToCarousel() {
        guard let current = currentPreview else { return }
        
        // Calculamos el porcentaje para el nombre (ej: +25%)
        let percentage = Int(brightnessValue * 100)
        let sign = percentage >= 0 ? "+" : ""
        let formattedName = "\(activeFilterName) (\(sign)\(percentage)%)"
        
        let newVersion = FilteredVersion(image: current, filterName: formattedName)
        
        // Insertamos al inicio de la lista con una animación de rebote
        withAnimation(.spring()) {
            savedVersions.insert(newVersion, at: 0)
        }
    }
    
    // Elimina una versión guardada
    func removeFromCarousel(id: UUID) {
        withAnimation { savedVersions.removeAll { $0.id == id } }
    }
}

// MARK: - 3. VISTAS (Interfaz de Usuario)
struct ContentView: View {
    @StateObject private var vm = FilterViewModel() // Instancia de nuestra lógica
    
    // Definición de filtros disponibles
    let colorFilters = [
        ("Sepia", "CISepiaTone"),
        ("Noir", "CIPhotoEffectNoir"),
        ("Cómic", "CIComicEffect"),
        ("Pixel", "CIPixellate")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // --- SECCIÓN 1: ÁREA DE PREVISUALIZACIÓN ---
                ZStack {
                    Color.white.ignoresSafeArea() // Fondo limpio estilo galería
                    
                    if let img = vm.currentPreview {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 330)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10)
                    } else {
                        // Mensaje cuando no hay foto cargada
                        ContentUnavailableView("Selecciona una foto", systemImage: "photo.badge.plus")
                    }
                    
                    // --- SLIDER LATERAL ---
                    if vm.originalImage != nil {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                // Llamada al componente personalizado del slider
                                VerticalBrightnessSlider(value: $vm.brightnessValue) {
                                    vm.applyAllFilters() // Al mover el dedo, procesamos la imagen
                                }
                                .frame(width: 30, height: 250)
                                
                                // Indicador numérico del brillo
                                Text("\(Int(vm.brightnessValue * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 25)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // --- SECCIÓN 2: SELECTOR DE FILTROS ---
                VStack(spacing: 10) {
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Botón Reset (Naranja)
                            Button(action: vm.resetEdits) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.headline).foregroundColor(.orange)
                                    .padding(10).background(Color.orange.opacity(0.1)).clipShape(Circle())
                            }
                            
                            // Botones de filtros generados dinámicamente
                            ForEach(colorFilters, id: \.1) { name, code in
                                Button(action: { vm.selectFilter(code: code, name: name) }) {
                                    Text(name).font(.system(size: 14, weight: .bold))
                                        .padding(.vertical, 8).padding(.horizontal, 18)
                                        // Azul si está activo, gris azulado si no
                                        .background(vm.activeFilterCode == code ? Color.blue : Color.blue.opacity(0.1))
                                        .foregroundColor(vm.activeFilterCode == code ? .white : .blue)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 15)

                // --- SECCIÓN 3: BOTÓN DE SELECCIÓN ---
                Button(action: vm.saveToCarousel) {
                    Label("Seleccionar", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity)
                        .background(vm.currentPreview == nil ? Color.gray : Color.blue)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 25).padding(.bottom, 20)
                .disabled(vm.currentPreview == nil) // Desactivado si no hay foto

                // --- SECCIÓN 4: CARRUSEL DE COMPARATIVA ---
                VStack(alignment: .leading, spacing: 5) {
                    Text("COMPARATIVA").font(.system(size: 10, weight: .black)).padding(.leading).padding(.top, 10)
                    
                    ZStack {
                        if vm.savedVersions.isEmpty {
                            Text("Añade versiones para comparar").font(.caption2).foregroundColor(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(vm.savedVersions) { version in
                                        VStack {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: version.image)
                                                    .resizable().scaledToFill()
                                                    .frame(width: 100, height: 150)
                                                    .clipped().cornerRadius(10)
                                                    .onTapGesture { vm.removeFromCarousel(id: version.id) }
                                                
                                                // Icono X para eliminar miniatura
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.4).clipShape(Circle()))
                                                    .padding(5)
                                            }
                                            Text(version.filterName)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1).frame(width: 100)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .background(Color.white) // Fondo blanco para separar la comparativa
            }
            .navigationTitle("FilterStack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Botón superior para abrir la galería
                PhotosPicker(selection: $vm.imageSelection, matching: .images) {
                    Image(systemName: "photo.badge.plus").font(.title3)
                }
            }
        }
    }
}

// MARK: - 4. COMPONENTE PERSONALIZADO: SLIDER VERTICAL
struct VerticalBrightnessSlider: View {
    @Binding var value: Float    // Enlazado al ViewModel
    var onChange: () -> Void     // Acción al cambiar el valor
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            // Normalizamos el valor de -1.0 a 1.0 para que SwiftUI entienda el porcentaje (0 a 1)
            let percentage = CGFloat((value + 1.0) / 2.0)
            
            ZStack(alignment: .bottom) {
                // El carril gris de fondo
                Capsule().fill(Color.gray.opacity(0.15)).frame(width: 6)
                
                // El relleno azul que sube y baja
                Capsule().fill(Color.blue).frame(width: 6).frame(height: height * percentage)
                
                // El círculo blanco que el usuario arrastra
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 3)
                    // Cálculo matemático para posicionar el círculo en la altura correcta
                    .offset(y: -height * percentage + 11)
            }
            .frame(width: geo.size.width)
            // LÓGICA DE GESTO: Convierte el arrastre del dedo en un número decimal
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let drag = 1.0 - (gesture.location.y / height)
                let newValue = Float(drag) * 2.0 - 1.0
                value = min(max(newValue, -1.0), 1.0) // Limitamos entre -1 y 1
                onChange() // Notificamos el cambio
            })
        }
    }
}
