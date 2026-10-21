const LAYER_BBOXES = {
  "osm:osm-tandil": [-59.141, -37.322, -59.133, -37.314],
  "overture:overture-buildings-argentina": [-58.386, -34.607, -58.378, -34.599],
  "osm:osm-mexico-df": [-99.137, 19.429, -99.129, 19.437],
};
const INITIAL_BBOX = LAYER_BBOXES["osm:osm-mexico-df"];
const MAX_AREA_KM2 = 1;
const WFS_PATH = "/geoserver/cloud/osm/ows";

const vectorSource = new ol.source.Vector();
const bboxSource = new ol.source.Vector();
const map = new ol.Map({
  target: "map",
  layers: [
    new ol.layer.Tile({ source: new ol.source.OSM() }),
    new ol.layer.Vector({
      source: bboxSource,
      style: new ol.style.Style({
        stroke: new ol.style.Stroke({ color: "#dc2626", width: 2, lineDash: [8, 5] }),
        fill: new ol.style.Fill({ color: "rgba(220, 38, 38, 0.04)" }),
      }),
    }),
    new ol.layer.Vector({
      source: vectorSource,
      style: new ol.style.Style({
        stroke: new ol.style.Stroke({ color: "rgba(194, 65, 12, 0.9)", width: 1 }),
        fill: new ol.style.Fill({ color: "rgba(251, 146, 60, 0.12)" }),
        image: new ol.style.Circle({
          radius: 3,
          fill: new ol.style.Fill({ color: "rgba(234, 88, 12, 0.75)" }),
          stroke: new ol.style.Stroke({ color: "#9a3412", width: 0.75 }),
        }),
      }),
    }),
  ],
  view: new ol.View({
    center: ol.proj.fromLonLat([-99.133, 19.433]),
    zoom: 17,
  }),
});

const form = document.querySelector("#query-form");
const submitButton = form.querySelector('button[type="submit"]');
const status = document.querySelector("#status");
const requestLink = document.querySelector("#request-url");

function readBbox() {
  return ["minx", "miny", "maxx", "maxy"].map((id) => Number(document.querySelector(`#${id}`).value));
}

function writeBbox(bbox) {
  ["minx", "miny", "maxx", "maxy"].forEach((id, index) => {
    document.querySelector(`#${id}`).value = bbox[index].toFixed(6);
  });
  drawBbox(bbox);
}

function areaKm2([minx, miny, maxx, maxy]) {
  const middleLatitude = (miny + maxy) / 2;
  const width = (maxx - minx) * 111.32 * Math.cos(middleLatitude * Math.PI / 180);
  const height = (maxy - miny) * 110.57;
  return width * height;
}

function validateBbox(bbox) {
  if (bbox.some((value) => !Number.isFinite(value))) throw new Error("El BBOX contiene valores inválidos.");
  if (bbox[0] >= bbox[2] || bbox[1] >= bbox[3]) throw new Error("El BBOX no tiene una extensión válida.");
  const area = areaKm2(bbox);
  if (area > MAX_AREA_KM2) throw new Error(`El BBOX cubre ${area.toFixed(2)} km². El máximo es ${MAX_AREA_KM2} km².`);
  return area;
}

function drawBbox(bbox) {
  bboxSource.clear();
  const extent = ol.proj.transformExtent(bbox, "EPSG:4326", "EPSG:3857");
  bboxSource.addFeature(new ol.Feature(ol.geom.Polygon.fromExtent(extent)));
}

function show(message, isError = false) {
  status.textContent = message;
  status.classList.toggle("error", isError);
}

document.querySelector("#layer-name").addEventListener("change", (event) => {
  const bbox = LAYER_BBOXES[event.target.value];
  writeBbox(bbox);
  map.getView().fit(ol.proj.transformExtent(bbox, "EPSG:4326", "EPSG:3857"), { padding: [60, 60, 60, 60] });
});

document.querySelector("#use-view").addEventListener("click", () => {
  const extent = map.getView().calculateExtent(map.getSize());
  writeBbox(ol.proj.transformExtent(extent, "EPSG:3857", "EPSG:4326"));
});

document.querySelector("#clear").addEventListener("click", () => {
  vectorSource.clear();
  show("Resultados eliminados.");
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const bbox = readBbox();

  try {
    const area = validateBbox(bbox);
    drawBbox(bbox);
    const maxFeatures = Math.min(500, Math.max(1, Number(document.querySelector("#max-features").value)));
    const params = new URLSearchParams({
      service: "WFS",
      version: "1.0.0",
      request: "GetFeature",
      typeName: document.querySelector("#layer-name").value,
      outputFormat: "application/json",
      maxFeatures: String(maxFeatures),
      srsName: "EPSG:4326",
    });
    const cql = document.querySelector("#cql").value.trim();
    const spatialFilter = "BBOX(geometry," + bbox.join(",") + ",'EPSG:4326')";
    const combinedFilter = cql ? spatialFilter + " AND (" + cql + ")" : spatialFilter;
    params.set("CQL_FILTER", combinedFilter);

    const url = `${WFS_PATH}?${params}`;
    requestLink.href = url;
    requestLink.textContent = url;
    submitButton.disabled = true;
    show(`Consultando ${area.toFixed(3)} km²…`);

    const response = await fetch(url, { headers: { Accept: "application/geo+json, application/json" } });
    const contentType = response.headers.get("content-type") || "";
    const body = await response.text();
    if (!response.ok || contentType.includes("xml") || body.trimStart().startsWith("<")) {
      const xml = new DOMParser().parseFromString(body, "application/xml");
      const message = xml.querySelector("ServiceException, ExceptionText")?.textContent?.trim();
      throw new Error(message || "GeoServer rechazó la consulta WFS.");
    }
    let payload;
    try {
      payload = JSON.parse(body);
    } catch {
      throw new Error("WFS no devolvió un documento GeoJSON válido.");
    }

    const features = new ol.format.GeoJSON().readFeatures(payload, {
      dataProjection: "EPSG:4326",
      featureProjection: map.getView().getProjection(),
    });
    vectorSource.clear();
    vectorSource.addFeatures(features);
    show(`GeoServer devolvió ${features.length} objetos para ${area.toFixed(3)} km².`);
  } catch (error) {
    show(error.message, true);
  } finally {
    submitButton.disabled = false;
  }
});

drawBbox(INITIAL_BBOX);
map.getView().fit(ol.proj.transformExtent(INITIAL_BBOX, "EPSG:4326", "EPSG:3857"), {
  padding: [60, 60, 60, 60],
});
