package com.ticket.app.backend.event;

import static org.assertj.core.api.Assertions.assertThat;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import javax.imageio.ImageIO;

import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * Cover images of events, bus trips, screenings and places: the owner uploads, changes and removes the
 * image of its own events, an admin may replace or remove any, anyone may fetch them, and what is stored
 * is always the processed picture, never the upload. Every test makes its own business and event, so
 * the demo's events and the other tests are never touched.
 */
class EventImagesApiTest extends ApiTest {

    private static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));

    @Test
    void anOwnerPutsAnImageOnItsEventAndAnyoneCanFetchIt() throws IOException {
        String owner = newBusiness("+85570002001", "Image Co One");
        String event = publishEvent(owner, "Image Concert One");
        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isNull();

        String url = read(putImage("/merchant/events/" + event + "/image", owner, png(800, 600, Color.RED))
                .expectStatus().isOk().expectBody(), "$.imageUrl");

        assertThat(url).matches("/images/events/" + event + "\\?v=\\d+");
        // The owner's own event, in its list and on its own, now says where the image is.
        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isEqualTo(url);
        assertThat(imageUrlInList("/merchant/events", owner, event)).isEqualTo(url);

        // Anyone may fetch it, with no sign-in. It is a JPEG, however it was sent.
        ResponseSpec shown = http.get().uri(url).exchange();
        byte[] bytes = shown.expectStatus().isOk()
                .expectHeader().contentType(MediaType.IMAGE_JPEG)
                .expectBody().returnResult().getResponseBody();
        BufferedImage picture = ImageIO.read(new ByteArrayInputStream(bytes));
        assertThat(picture.getWidth()).isEqualTo(800);
        assertThat(picture.getHeight()).isEqualTo(600);
        assertThat(isJpeg(bytes)).isTrue();
        // The red it was painted is still red.
        int middle = picture.getRGB(400, 300);
        assertThat((middle >> 16) & 0xFF).isGreaterThan(200);
        assertThat(middle & 0xFF).isLessThan(60);
    }

    @Test
    void aBigPictureIsShrunkAndATransparentOneIsPutOnWhite() throws IOException {
        String owner = newBusiness("+85570002002", "Image Co Two");
        String event = publishEvent(owner, "Image Concert Two");

        // 3000 x 1500 becomes 1280 x 640, the same shape.
        String big = read(putImage("/merchant/events/" + event + "/image", owner, png(3000, 1500, Color.BLUE))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        BufferedImage shrunk = ImageIO.read(new ByteArrayInputStream(fetch(big)));
        assertThat(shrunk.getWidth()).isEqualTo(1280);
        assertThat(shrunk.getHeight()).isEqualTo(640);

        // A fully transparent PNG has no colour of its own: it ends up white, not black.
        BufferedImage clear = new BufferedImage(200, 100, BufferedImage.TYPE_INT_ARGB);
        String flat = read(putImage("/merchant/events/" + event + "/image", owner, encode(clear, "png"))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        int corner = ImageIO.read(new ByteArrayInputStream(fetch(flat))).getRGB(5, 5);
        assertThat((corner >> 16) & 0xFF).isGreaterThan(240);
        assertThat((corner >> 8) & 0xFF).isGreaterThan(240);
        assertThat(corner & 0xFF).isGreaterThan(240);
    }

    @Test
    void aNewPictureHasANewAddressAndRemovingItTakesItDown() throws IOException {
        String owner = newBusiness("+85570002003", "Image Co Three");
        String event = publishEvent(owner, "Image Concert Three");

        String first = read(putImage("/merchant/events/" + event + "/image", owner, png(300, 200, Color.GREEN))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        // The version is the time it was set, to the millisecond: wait one out so the two differ.
        sleep(5);
        String second = read(putImage("/merchant/events/" + event + "/image", owner, png(300, 200, Color.ORANGE))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        assertThat(second).isNotEqualTo(first);
        assertThat(second).startsWith("/images/events/" + event);

        delete("/merchant/events/" + event + "/image", owner).expectStatus().isNoContent();
        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isNull();
        http.get().uri(second).exchange().expectStatus().isNotFound();
        // Removing it again is fine: there is simply nothing to remove.
        delete("/merchant/events/" + event + "/image", owner).expectStatus().isNoContent();
    }

    @Test
    void theImageCanBeKeptForAYearOnlyByItsCurrentVersion() throws IOException {
        String owner = newBusiness("+85570002004", "Image Co Four");
        String event = publishEvent(owner, "Image Concert Four");
        String url = read(putImage("/merchant/events/" + event + "/image", owner, png(120, 80, Color.CYAN))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        String path = "/images/events/" + event;

        // Its own address (with ?v=): a new picture would have a new address, so it never goes stale.
        http.get().uri(url).exchange().expectStatus().isOk()
                .expectHeader().value(HttpHeaders.CACHE_CONTROL, value -> assertThat(value)
                        .contains("max-age=31536000").contains("immutable").contains("public"));
        // Without it, or with an old one, a cache must ask again.
        ResponseSpec plain = http.get().uri(path).exchange();
        plain.expectStatus().isOk()
                .expectHeader().value(HttpHeaders.CACHE_CONTROL, value -> assertThat(value)
                        .contains("no-cache").doesNotContain("immutable"));
        String etag = plain.expectBody().returnResult().getResponseHeaders().getETag();
        assertThat(etag).isNotBlank();
        http.get().uri(path + "?v=1").exchange().expectStatus().isOk()
                .expectHeader().value(HttpHeaders.CACHE_CONTROL, value -> assertThat(value).doesNotContain("immutable"));

        // Asking again with the ETag it was given: nothing changed, so nothing is sent.
        http.get().uri(path).header(HttpHeaders.IF_NONE_MATCH, etag).exchange().expectStatus().isNotModified();
    }

    @Test
    void anythingThatIsNotAPictureIsRefused() throws IOException {
        String owner = newBusiness("+85570002005", "Image Co Five");
        String event = publishEvent(owner, "Image Concert Five");
        String path = "/merchant/events/" + event + "/image";
        String notAPicture = "That file is not a picture. Choose a JPEG or PNG image.";

        // Text with a picture's name, a PDF-like start, and a file cut short.
        putImage(path, owner, "hello, I am not a picture".getBytes(StandardCharsets.UTF_8))
                .expectStatus().isBadRequest().expectBody().jsonPath("$.message").isEqualTo(notAPicture);
        putImage(path, owner, "%PDF-1.7 not really".getBytes(StandardCharsets.UTF_8))
                .expectStatus().isBadRequest().expectBody().jsonPath("$.message").isEqualTo(notAPicture);
        byte[] whole = png(400, 300, Color.MAGENTA);
        putImage(path, owner, java.util.Arrays.copyOf(whole, whole.length / 3))
                .expectStatus().isBadRequest().expectBody().jsonPath("$.message").isEqualTo(notAPicture);
        // A real picture of a kind Pin does not take (GIF).
        putImage(path, owner, encode(new BufferedImage(50, 50, BufferedImage.TYPE_INT_RGB), "gif"))
                .expectStatus().isBadRequest().expectBody().jsonPath("$.message").isEqualTo(notAPicture);
        // Nothing at all.
        putImage(path, owner, new byte[0])
                .expectStatus().isBadRequest().expectBody().jsonPath("$.message").isEqualTo("Choose a picture to upload.");

        // And none of that left an image behind.
        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isNull();
    }

    @Test
    void aPictureOverFiveMegabytesIsRefused() throws IOException {
        String owner = newBusiness("+85570002006", "Image Co Six");
        String event = publishEvent(owner, "Image Concert Six");

        putImage("/merchant/events/" + event + "/image", owner, new byte[5 * 1024 * 1024 + 100])
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("That picture is too big. Keep it under 5 MB.");
    }

    @Test
    void onlyTheOwnerOfTheEventChangesItsImage() throws IOException {
        String owner = newBusiness("+85570002007", "Image Co Seven");
        String event = publishEvent(owner, "Image Concert Seven");
        String path = "/merchant/events/" + event + "/image";
        byte[] picture = png(100, 100, Color.RED);

        // Another business's owner does not even find the event.
        String other = newBusiness("+85570002008", "Image Co Eight");
        putImage(path, other, picture).expectStatus().isNotFound();
        delete(path, other).expectStatus().isNotFound();
        // A scanner of the business is not the owner. (The demo's scanner works for the demo business.)
        String scanner = accessTokenFor(SECOND_SCANNER);
        putImage("/merchant/events/" + demoEventId() + "/image", scanner, picture).expectStatus().isForbidden();
        delete("/merchant/events/" + demoEventId() + "/image", scanner).expectStatus().isForbidden();
        // A buyer and a caller with no sign-in have no business here.
        String buyer = registerBuyer("+85570002009", "Image Buyer", "female");
        putImage(path, buyer, picture).expectStatus().isForbidden();
        http.put().uri(path).contentType(MediaType.IMAGE_PNG).body(picture).exchange().expectStatus().isUnauthorized();
        http.delete().uri(path).exchange().expectStatus().isUnauthorized();

        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isNull();
    }

    @Test
    void anAdminReplacesOrRemovesAnyEventsImageAndSeesItInTheList() throws IOException {
        String owner = newBusiness("+85570002010", "Image Co Ten");
        String event = publishEvent(owner, "Image Concert Ten");
        String ownersUrl = read(putImage("/merchant/events/" + event + "/image", owner, png(200, 100, Color.RED))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        sleep(5);

        String adminsUrl = read(http.put().uri("/admin/events/" + event + "/image")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken())
                .contentType(MediaType.IMAGE_PNG).body(png(200, 100, Color.BLUE)).exchange()
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        assertThat(adminsUrl).isNotEqualTo(ownersUrl);
        assertThat(imageUrlInList("/admin/events", adminToken(), event)).isEqualTo(adminsUrl);
        assertThat(ImageIO.read(new ByteArrayInputStream(fetch(adminsUrl))).getRGB(100, 50) & 0xFF).isGreaterThan(200);

        http.delete().uri("/admin/events/" + event + "/image")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken()).exchange().expectStatus().isNoContent();
        assertThat(JsonPathOf(get("/merchant/events/" + event, owner), "$.imageUrl")).isNull();
        assertThat(imageUrlInList("/admin/events", adminToken(), event)).isNull();

        // An event that does not exist, and a merchant trying the admin's endpoints.
        http.put().uri("/admin/events/00000000-0000-7000-8000-00000000dead/image")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken())
                .contentType(MediaType.IMAGE_PNG).body(png(10, 10, Color.RED)).exchange().expectStatus().isNotFound();
        http.put().uri("/admin/events/" + event + "/image")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + owner)
                .contentType(MediaType.IMAGE_PNG).body(png(10, 10, Color.RED)).exchange().expectStatus().isForbidden();
    }

    @Test
    void buyersSeeTheImageOnEventsAndOnPlaces() throws IOException {
        String owner = newBusiness("+85570002011", "Image Co Eleven");
        String event = publishEvent(owner, "Image Concert Eleven");
        approveEvent(event);
        String buyer = registerBuyer("+85570002012", "Image Buyer Two", "male");

        // On sale with no picture: the field is there, and empty.
        assertThat(JsonPathOf(get("/catalog/events/" + event, buyer), "$.imageUrl")).isNull();
        String url = read(putImage("/merchant/events/" + event + "/image", owner, png(640, 360, Color.PINK))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        assertThat(JsonPathOf(get("/catalog/events/" + event, buyer), "$.imageUrl")).isEqualTo(url);
        assertThat(imageUrlInList("/catalog/events", buyer, event)).isEqualTo(url);

        // A place too: an admission business puts a picture on its place.
        String park = registerBusiness("+85570002013", "Image Park Co", "admission");
        approveBusinessOf(park);
        String place = read(post("/merchant/events/places", Map.of("name", "Image Park Twelve", "venue", "Image Park",
                "ticketTypes", List.of(Map.of("name", "Adult", "priceCents", 500))), park)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(place);
        String placeUrl = read(putImage("/merchant/events/" + place + "/image", park, png(500, 500, Color.YELLOW))
                .expectStatus().isOk().expectBody(), "$.imageUrl");
        assertThat(JsonPathOf(get("/catalog/places/" + place, buyer), "$.imageUrl")).isEqualTo(placeUrl);
    }

    @Test
    void anEventWithNoImageHasNoAddressToFetch() {
        http.get().uri("/images/events/00000000-0000-7000-8000-00000000dead").exchange().expectStatus().isNotFound();
        http.get().uri("/images/events/not-an-id").exchange().expectStatus().isNotFound();
        // Only /images/events/{id} is public: the folder itself is not.
        http.get().uri("/images/").exchange().expectStatus().isUnauthorized();
        http.get().uri("/images/events").exchange().expectStatus().isUnauthorized();
    }

    // ---------------------------------------------------------------------------------------------

    private String newBusiness(String phone, String name) {
        String owner = registerBusiness(phone, name);
        approveBusinessOf(owner);
        return owner;
    }

    /** A concert 9 days out: the business's own, so no other test sees it. Returns its ID. */
    private String publishEvent(String owner, String name) {
        return read(post("/merchant/events", Map.of("name", name, "kind", "concert",
                "startsAt", TODAY.plusDays(9) + "T20:00:00", "venue", "Image Hall",
                "ticketTypes", List.of(Map.of("name", "Standard", "priceCents", 1000, "quantity", 50))), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
    }

    /** An event of the demo business, to aim a scanner's call at. */
    private String demoEventId() {
        return read(get("/merchant/events", accessTokenFor(OWNER)).expectStatus().isOk().expectBody(), "$[0].id");
    }

    private ResponseSpec putImage(String path, String token, byte[] picture) {
        return http.put().uri(path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                .contentType(MediaType.IMAGE_PNG)
                .body(picture)
                .exchange();
    }

    private ResponseSpec delete(String path, String token) {
        return http.delete().uri(path).header(HttpHeaders.AUTHORIZATION, "Bearer " + token).exchange();
    }

    /** The picture at this address, with no sign-in. */
    private byte[] fetch(String url) {
        return http.get().uri(url).exchange().expectStatus().isOk().expectBody().returnResult().getResponseBody();
    }

    private Object JsonPathOf(ResponseSpec response, String path) {
        return read(response.expectStatus().isOk().expectBody(), path);
    }

    /** The {@code imageUrl} of the one event with this ID in a list response; null when it has none. */
    private Object imageUrlInList(String listPath, String token, String eventId) {
        List<Object> found = read(get(listPath, token).expectStatus().isOk().expectBody(),
                "$[?(@.id=='" + eventId + "')].imageUrl");
        assertThat(found).as("the event is in the list exactly once").hasSize(1);
        return found.get(0);
    }

    private static byte[] png(int width, int height, Color colour) throws IOException {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = image.createGraphics();
        graphics.setColor(colour);
        graphics.fillRect(0, 0, width, height);
        graphics.dispose();
        return encode(image, "png");
    }

    private static byte[] encode(BufferedImage image, String format) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, format, out);
        return out.toByteArray();
    }

    /** JPEG files start with FF D8 FF. */
    private static boolean isJpeg(byte[] bytes) {
        return bytes.length > 3 && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF;
    }

    private static void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
