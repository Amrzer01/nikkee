import './fonts.css';
import './runway.css';
import { stylingBag } from './runway/bag';
import { registerRunwaySection } from './runway/element';

registerRunwaySection();
stylingBag.mount(document);
