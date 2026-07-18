export function Avatar({ imageUrl, initials, alt, size = "small" }: {
  imageUrl: string | null;
  initials: string;
  alt: string;
  size?: "small" | "large";
}) {
  const sizeClass = size === "large" ? "size-20 text-xl sm:size-24 sm:text-2xl" : "size-11 text-sm";
  return (
    <span className={`relative inline-grid shrink-0 place-items-center overflow-hidden rounded-full border-2 border-white bg-[var(--sitaa-blue)] font-bold text-white shadow-md ring-1 ring-blue-950/20 ${sizeClass}`}>
      {imageUrl ? (
        // La URL se valida como HTTPS de googleusercontent.com antes de llegar al componente.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={imageUrl} alt={alt} className="h-full w-full object-cover" referrerPolicy="no-referrer" />
      ) : <span aria-hidden="true">{initials}</span>}
    </span>
  );
}
