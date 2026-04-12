import React, { useRef, useEffect } from 'react'

const STAR_COUNT = 160
const COLORS = ['#ffffff', '#c8d8ff', '#ffe8c8', '#c8f0ff']

export default function Starfield() {
  const canvasRef = useRef(null)
  const starsRef = useRef([])
  const rafRef = useRef(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')

    const resize = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resize()
    window.addEventListener('resize', resize)

    // Initialize stars with individual breathing rhythms
    starsRef.current = Array.from({ length: STAR_COUNT }, () => ({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: Math.random() * 1.4 + 0.3,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      // Each star breathes at its own rhythm
      phase: Math.random() * Math.PI * 2,
      speed: 0.003 + Math.random() * 0.008,
      minOpacity: 0.05 + Math.random() * 0.15,
      maxOpacity: 0.4 + Math.random() * 0.5,
    }))

    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      for (const star of starsRef.current) {
        star.phase += star.speed
        const breathe = (Math.sin(star.phase) + 1) / 2
        const opacity = star.minOpacity + breathe * (star.maxOpacity - star.minOpacity)

        ctx.beginPath()
        ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2)
        ctx.fillStyle = star.color
        ctx.globalAlpha = opacity
        ctx.fill()

        // Subtle glow on brighter stars
        if (star.r > 1.0 && opacity > 0.5) {
          ctx.beginPath()
          ctx.arc(star.x, star.y, star.r * 3, 0, Math.PI * 2)
          ctx.fillStyle = star.color
          ctx.globalAlpha = opacity * 0.06
          ctx.fill()
        }
      }

      ctx.globalAlpha = 1
      rafRef.current = requestAnimationFrame(draw)
    }

    draw()

    return () => {
      window.removeEventListener('resize', resize)
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 0,
        pointerEvents: 'none',
      }}
    />
  )
}
