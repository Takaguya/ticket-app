package com.ticket.app.backend.event.service;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.Image;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Locale;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;

import com.ticket.app.backend.shared.model.BusinessRuleException;

/**
 * Turns an uploaded picture into the one Pin stores: a JPEG, at most {@value #MAX_SIDE} pixels on
 * its longest side. The upload is never kept as it came, which
 *
 * <ul>
 *   <li>proves it is a picture (a renamed file of another kind is refused),</li>
 *   <li>removes what a phone photo carries besides the picture, such as where it was taken,</li>
 *   <li>and keeps every stored image small and in one format for the apps.</li>
 * </ul>
 *
 * Only JPEG and PNG are accepted; transparency is flattened onto white.
 */
final class ImageNormalizer {

    /** The biggest upload read. */
    static final int MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

    static final int MAX_SIDE = 1280;

    /** The stored picture's type. */
    static final String CONTENT_TYPE = "image/jpeg";

    /** A picture this big is refused before it is decoded: it would take far more memory than its file size. */
    private static final long MAX_PIXELS = 40_000_000L;

    private static final float QUALITY = 0.85f;

    private static final String NOT_A_PICTURE = "That file is not a picture. Choose a JPEG or PNG image.";

    private ImageNormalizer() {
    }

    /** The processed picture's bytes ({@value #CONTENT_TYPE}). */
    static byte[] normalize(byte[] upload) {
        if (upload == null || upload.length == 0) {
            throw BusinessRuleException.invalid("Choose a picture to upload.");
        }
        if (upload.length > MAX_UPLOAD_BYTES) {
            throw BusinessRuleException.invalid("That picture is too big. Keep it under 5 MB.");
        }
        BufferedImage source = decode(upload);
        return encode(scaled(source));
    }

    private static BufferedImage decode(byte[] upload) {
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(upload))) {
            Iterator<ImageReader> readers = input == null ? null : ImageIO.getImageReaders(input);
            if (readers == null || !readers.hasNext()) {
                throw BusinessRuleException.invalid(NOT_A_PICTURE);
            }
            ImageReader reader = readers.next();
            try {
                String format = reader.getFormatName().toLowerCase(Locale.ROOT);
                if (!format.equals("jpeg") && !format.equals("png")) {
                    throw BusinessRuleException.invalid(NOT_A_PICTURE);
                }
                reader.setInput(input, true, true);
                long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
                if (pixels > MAX_PIXELS) {
                    throw BusinessRuleException.invalid("That picture is too large. Use one under 40 megapixels.");
                }
                return reader.read(0);
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException e) {
            if (e instanceof BusinessRuleException refused) {
                throw refused;
            }
            // A truncated or damaged file: the readers say so in many ways.
            throw BusinessRuleException.invalid(NOT_A_PICTURE);
        }
    }

    /** At most {@link #MAX_SIDE} on the longest side, on a white background, without transparency. */
    private static BufferedImage scaled(BufferedImage source) {
        int width = source.getWidth();
        int height = source.getHeight();
        double ratio = Math.min(1.0, (double) MAX_SIDE / Math.max(width, height));
        int newWidth = Math.max(1, (int) Math.round(width * ratio));
        int newHeight = Math.max(1, (int) Math.round(height * ratio));

        Image drawn = ratio < 1.0 ? source.getScaledInstance(newWidth, newHeight, Image.SCALE_AREA_AVERAGING) : source;
        BufferedImage target = new BufferedImage(newWidth, newHeight, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = target.createGraphics();
        try {
            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            graphics.setColor(Color.WHITE);
            graphics.fillRect(0, 0, newWidth, newHeight);
            graphics.drawImage(drawn, 0, 0, null);
        } finally {
            graphics.dispose();
        }
        return target;
    }

    private static byte[] encode(BufferedImage image) {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             ImageOutputStream stream = ImageIO.createImageOutputStream(out)) {
            ImageWriteParam params = writer.getDefaultWriteParam();
            params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            params.setCompressionQuality(QUALITY);
            writer.setOutput(stream);
            writer.write(null, new IIOImage(image, null, null), params);
            stream.flush();
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Could not encode the image", e);
        } finally {
            writer.dispose();
        }
    }
}
