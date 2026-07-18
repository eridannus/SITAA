"use client";

import { useEffect, useRef } from "react";

type NodePoint = { x: number; y: number; vx: number; vy: number; radius: number };

export function NodeNetworkBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let nodes: NodePoint[] = [];
    let frame = 0;
    let visible = !document.hidden;
    let viewportWidth = 1;
    let viewportHeight = 1;

    const resize = () => {
      const bounds = canvas.getBoundingClientRect();
      const width = Math.max(1, Math.round(bounds.width));
      const height = Math.max(1, Math.round(bounds.height));
      const ratio = Math.min(window.devicePixelRatio || 1, 1.75);
      viewportWidth = width;
      viewportHeight = height;
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      const count = Math.max(18, Math.min(58, Math.round((width * height) / 26000)));
      nodes = Array.from({ length: count }, (_, index) => ({
        x: (index * 97 + Math.random() * width) % width,
        y: (index * 61 + Math.random() * height) % height,
        vx: (Math.random() - 0.5) * 0.08,
        vy: -(0.06 + Math.random() * 0.12),
        radius: 1.1 + Math.random() * 1.6,
      }));
    };

    const draw = (move: boolean) => {
      const width = viewportWidth;
      const height = viewportHeight;
      context.clearRect(0, 0, width, height);
      const gradient = context.createLinearGradient(0, height, width, 0);
      gradient.addColorStop(0, "rgba(0, 43, 92, 0.08)");
      gradient.addColorStop(1, "rgba(201, 162, 39, 0.04)");
      context.fillStyle = gradient;
      context.fillRect(0, 0, width, height);

      for (let first = 0; first < nodes.length; first += 1) {
        const node = nodes[first];
        if (move) {
          node.x += node.vx;
          node.y += node.vy;
          if (node.y < -12) { node.y = height + 12; node.x = Math.random() * width; }
          if (node.x < -12) node.x = width + 12;
          if (node.x > width + 12) node.x = -12;
        }
        for (let second = first + 1; second < nodes.length; second += 1) {
          const peer = nodes[second];
          const distance = Math.hypot(node.x - peer.x, node.y - peer.y);
          if (distance < 132) {
            context.beginPath();
            context.moveTo(node.x, node.y);
            context.lineTo(peer.x, peer.y);
            context.strokeStyle = `rgba(0, 43, 92, ${0.12 * (1 - distance / 132)})`;
            context.lineWidth = 0.75;
            context.stroke();
          }
        }
        context.beginPath();
        context.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
        context.fillStyle = first % 7 === 0 ? "rgba(201, 162, 39, 0.5)" : "rgba(0, 43, 92, 0.35)";
        context.fill();
      }
    };

    const animate = () => {
      if (!visible || reducedMotion.matches) return;
      draw(true);
      frame = window.requestAnimationFrame(animate);
    };
    const restart = () => {
      window.cancelAnimationFrame(frame);
      draw(false);
      if (visible && !reducedMotion.matches) frame = window.requestAnimationFrame(animate);
    };
    const onVisibility = () => { visible = !document.hidden; restart(); };

    resize();
    restart();
    window.addEventListener("resize", resize);
    window.addEventListener("resize", restart);
    window.visualViewport?.addEventListener("resize", resize);
    window.visualViewport?.addEventListener("resize", restart);
    document.addEventListener("visibilitychange", onVisibility);
    reducedMotion.addEventListener("change", restart);
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener("resize", resize);
      window.removeEventListener("resize", restart);
      window.visualViewport?.removeEventListener("resize", resize);
      window.visualViewport?.removeEventListener("resize", restart);
      document.removeEventListener("visibilitychange", onVisibility);
      reducedMotion.removeEventListener("change", restart);
    };
  }, []);

  return <canvas ref={canvasRef} aria-hidden="true" className="sitaa-node-canvas" />;
}
