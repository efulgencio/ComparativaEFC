# FilterStack 📸

**FilterStack** es un editor de fotografía minimalista y de alto rendimiento desarrollado en un único fichero de **SwiftUI**. Permite aplicar filtros artísticos y ajustes de brillo de forma acumulativa sin perder la calidad de la imagen original.

## 📺 Demo del Funcionamiento

Aquí puedes ver cómo funciona la aplicación, el ajuste de brillo en tiempo real y la comparativa de versiones:


<video src="https://github.com/efulgencio/ComparativaEFC/blob/main/comparativa_fotos.mov?raw=true" width="300" controls></video>

## ✨ Características Principales

* **Procesamiento No Destructivo:** Los ajustes se calculan siempre desde la foto original para evitar la pérdida de calidad.
* **Filtros + Brillo:** Puedes aplicar un filtro (Sepia, Noir, etc.) y ajustar el brillo de forma independiente; ambos efectos se suman.
* **Control de Brillo Vertical:** Slider personalizado que muestra el nivel de intensidad numérica (de -100% a +100%).
* **Carrusel de Comparativa:** Guarda tus ediciones favoritas en una bandeja inferior para comparar resultados rápidamente.
* **Fondo Blanco Infinito:** Interfaz limpia diseñada para que los colores de la fotografía sean los protagonistas.

## 🛠️ Tecnologías

* **SwiftUI:** Para una interfaz moderna y reactiva.
* **Core Image:** El motor de Apple para el procesamiento de imágenes por hardware (GPU).
* **PhotosUI:** Integración segura con la galería del iPhone.



## 🚀 Cómo instalarlo

Este proyecto está diseñado para ser extremadamente sencillo de probar:

1. Crea un nuevo proyecto de **SwiftUI** en Xcode.
2. Abre el archivo `ContentView.swift`.
3. Borra el contenido actual y pega el código completo del proyecto.
4. Asegúrate de que tu archivo de video se llame `comparativa_fotos.mov` si deseas mostrar la demo en GitHub.

---
Desarrollado en 2026 como ejemplo de integración de Core Image en SwiftUI.
